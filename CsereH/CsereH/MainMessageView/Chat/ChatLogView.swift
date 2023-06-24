//
//  ChatLogview.swift
//  CsereH
//
//  Created by Himanshu Vinchurkar on 05/06/23.
//

import SwiftUI
import Combine
import Firebase

class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @State var shouldShowImagePicker = false
    
    @Published var chatMessages = [ChatMessage]()
    
    var chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        
        fetchMessages()
    }
    
    
    var firestoreListener: ListenerRegistration?
    
     func fetchMessages() {
        guard let fromId =
                FirebaseManager.shared.auth.currentUser?.uid
        else {return}
        
        guard let toId = chatUser?.uid else { return}
         firestoreListener?.remove()
         chatMessages.removeAll()
            firestoreListener = FirebaseManager.shared.firestore
             .collection(FirebaseConstants.messages)
                .document(fromId)
                .collection(toId)
                .order(by: FirebaseConstants.timestamp)
                .addSnapshotListener{
                    querySnapshot, error in
                    if let error = error {
                        self.errorMessage = "Failed to listen for messages:   \(error)"
                        print(error)
                        return
                    }
                    
                    querySnapshot?.documentChanges.forEach({
                        change in
                        if change.type == .added {

                        do {
                                let cm = try change.document.data(as: ChatMessage.self)
                                self.chatMessages.append(cm)
                                print("Appending chatMessage in ChatlogView")
                            }
                            catch {
                                print("Failed to decode message:\(error)")
                            }
//                            let data = change.document.data()
//                            self.chatMessages.append(.init(domumentId: change.document.documentID, data: data))
                        }
                    })
                    
                    DispatchQueue.main.async {
                        self.count += 1
                    }
                    
                }
        
    }
//Used for sendng message in bubble
    func handleSend() {
//        print(chatText)
        guard let fromId =
                FirebaseManager.shared.auth.currentUser?.uid
        else {return}
        
        guard let toId = chatUser?.uid else { return
            
        }
        let document =
        FirebaseManager.shared.firestore.collection(FirebaseConstants.messages)
            .document(fromId)
            .collection(toId)
            .document()
        
        let messageData = ChatMessage(id: nil, fromId: fromId, toId: toId, text: chatText, timestamp: Date())
        
//        let messageData = [FirebaseConstants.fromId: fromId, FirebaseConstants.toId: toId, FirebaseConstants.text:self.chatText, "timestamp": Timestamp()] as [String:Any]
        
        try? document.setData(from: messageData) {
            error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore:\(error)"
                return
            }
            
//            print("Successfully saved current user sending message")
            
            self.persistRecentMessage()
            
            self.chatText = ""
            self.count += 1
        }
        
        let recipientMessageDocument  =
        FirebaseManager.shared.firestore.collection("messages")
            .document(toId)
            .collection(fromId)
            .document()
        
        try? recipientMessageDocument.setData(from:messageData) {
            error in
            if let error = error {
                print(error)
                self.errorMessage = "Failed to save message into Firestore:\(error)"
                return
            }
            
//            print("Recipient saved message as well")
        }
    }
    
    
    private func persistRecentMessage() {
        guard let chatUser = chatUser else {return}
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            return
        }
        guard let toId = self.chatUser?.uid else {return}
        
        let document = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(uid)
            .collection(FirebaseConstants.messages)
            .document(toId)
        
        let data = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId:uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: chatUser.profileImageUrl,
            FirebaseConstants.email: chatUser.email
        ] as [String: Any]
        
        document.setData(data){
            error in
            if let error = error {
                self.errorMessage = "Failed to save recent message\(error)"
                print("Failed to save recent message\(error)")
            }
        }
        
        
        guard let currentUser = FirebaseManager.shared.currentUser else { return }
        let recipientRecentMessageDictionary = [
            FirebaseConstants.timestamp: Timestamp(),
            FirebaseConstants.text: self.chatText,
            FirebaseConstants.fromId: uid,
            FirebaseConstants.toId: toId,
            FirebaseConstants.profileImageUrl: currentUser.profileImageUrl,
            FirebaseConstants.email: currentUser.email
        ] as [String : Any]
        
        FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(toId)
            .collection(FirebaseConstants.messages)
            .document(currentUser.uid)
            .setData(recipientRecentMessageDictionary) { error in
                if let error = error {
                    print("Failed to save recipient recent message: \(error)")
                    return
                }
            }
        
    }
    
    @Published var count = 0
}

struct ChatLogView: View {
    
//    let chatUser: ChatUser?
//    
//    init(chatUser: ChatUser?) {
//        self.chatUser = chatUser
//        self.vm = .init(chatUser: chatUser)
//    }
    
    
    @ObservedObject var vm: ChatLogViewModel
    
    
    var body: some View {
        ZStack {
            messagesView
            Text(vm.errorMessage)
        }
        .navigationTitle(vm.chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            vm.firestoreListener?.remove()
        }
//        .navigationBarItems(trailing: Button(action: {
//            vm.count += 1
//        }, label: {
//            Text("Count: \(vm.count)")
//        }))
    }
    
    static let emptyScrollToString = "Empty"
    
    private var messagesView: some View {
        VStack {
            ScrollView {
                ScrollViewReader {
                    ScrollViewProxy in
                    VStack {
                        ForEach(vm.chatMessages) { message in
                            MessageView(message: message)
                    }
                        HStack{Spacer()}
                            .id(Self.emptyScrollToString)
                    }
                    
                    .onReceive(vm.$count) { _ in
                        withAnimation(.easeIn(duration: 0.5)) {
                            ScrollViewProxy.scrollTo(Self.emptyScrollToString, anchor: .bottom)}
                        }
                        
                    
                        
                }
                   
                
               
            }
            .background(Color(.init(white: 0.95, alpha: 1)))
            .safeAreaInset(edge: .bottom) {
                chatBottomBar
                    .background(Color(
                        .systemBackground)
                        .ignoresSafeArea())
            }
        }
    }
    
    private var chatBottomBar:  some View {
        HStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size:24))
                .foregroundColor(Color(.darkGray))
            
            ZStack {
                DescriptionPlaceholder()
                TextEditor(text: $vm.chatText)
                    .opacity(vm.chatText.isEmpty ? 0.5 : 1)
            }
            .frame(height: 40)
            
            
            Button {
                vm.handleSend()
            } label: {
                Text("Send")
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(30)
        }
        
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
        
}

struct MessageView: View {
    
    let message: ChatMessage
    
    var body: some View {
        VStack {
            if message.fromId ==
                FirebaseManager.shared.auth.currentUser?.uid {
                HStack{
                    Spacer()
                    HStack {
                        Text(message.text)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(25)
                }
                
                
            } else {
                HStack{
                    
                    HStack {
                        Text(message.text)
                            .foregroundColor(.black)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(25)
                    Spacer()
                }
                
                
            }
        }
        
        .padding(.horizontal)
        .padding(.top, 8)}
}

private struct DescriptionPlaceholder: View {
    var body: some View {
        HStack {
            Text("Text Here")
                .foregroundColor(Color(.gray))
                .font(.system(size: 17))
                .padding(.leading, 5)
                .padding(.top, -4)
            Spacer()
        }
    }
}

struct ChatLogview_Previews: PreviewProvider {
    static var previews: some View {
//        NavigationView {
//            ChatLogView(chatUser: .init(data: ["uid": "LuYkcpaDtuOkFXSgwO6lQyITh2n2",
//                                               "email": "himanshu@gmail.com"]))
//        }
        
        MainMessagesView()
    }
}
