import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestoreSwift





class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isUserCurrentlyLoggedOut = false
    
    init() {
        DispatchQueue.main.async {
            self.isUserCurrentlyLoggedOut = FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        
        fetchRecentMessages()
    }
    
    @Published var recentMessages = [RecentMessage]()
    
    private var firestoreListener: ListenerRegistration?
    
    func fetchRecentMessages() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {return}
        
        firestoreListener?.remove()
        
        self.recentMessages.removeAll()
        
        
        firestoreListener = FirebaseManager.shared.firestore
            .collection(FirebaseConstants.recentMessages)
            .document(uid)
            .collection(FirebaseConstants.messages)
            .order(by: FirebaseConstants.timestamp)
            .addSnapshotListener{ querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for recent messages: \(error)"
                    print(error)
                    return
                }
                
                querySnapshot?.documentChanges.forEach({change in
//                    if change.type == .added {
                        let docId = change.document.documentID
                    
                    if let index =
                        self.recentMessages.firstIndex(where: {rm in
                            return rm.id == docId
                        }) {
                        self.recentMessages.remove(at: index)
                    }
                    
                    do {
                        let rm = try change.document.data(as: RecentMessage.self)
                            self.recentMessages.insert(rm, at: 0)
                        }
                     catch {
                        print(error)
                    }
                    
                    
                })
            }
    }
    
    func fetchCurrentUser() {
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        //self.errorMessage = "\(uid)"
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Failed to fetch current user: \(error)"
                print("Failed to fetch current user:", error)
                return
            }
            
            self.chatUser = try? snapshot?.data(as: ChatUser.self)
            FirebaseManager.shared.currentUser = self.chatUser
            
            //         self.errorMessage = "123"
            
//            guard let data = snapshot?.data() else {
//                self.errorMessage = "No data found"
//                return
//
//            }
//
//            self.chatUser = .init(data: data)

        }
    }
        
       
        
        func handleSignOut(){
            isUserCurrentlyLoggedOut.toggle()
            try? FirebaseManager.shared.auth.signOut()
        }
    }
    

struct MainMessagesView: View {
    
    @State var shouldShowLogOutOptions = false
    
    @State var shouldNavigateToChatLogView = false
    
    @ObservedObject private var vm = MainMessagesViewModel()
    
    private var chatLogViewModel = ChatLogViewModel(chatUser:nil)
    
    var body: some View {
//      Added Navigation stack for navigationLink
        NavigationStack {
            
            VStack {
//                Text("User: \(vm.chatUser?.uid ?? "")")
                
                customNavBar
                messagesView
 
// [New Method Naviagtionview For IOS16]/[It is must be in navigation Stack]
                    .navigationDestination(isPresented: $shouldNavigateToChatLogView) {
                        ChatLogView(vm: chatLogViewModel)
                    }
// [Old Method] [It is depricated in IOS 16]
//                NavigationLink("", isActive:
//                                $shouldNavigateToChatLogView) {
//                    ChatLogView(vm: chatLogViewModel)
//                }
            }
            .overlay(
                newMessageButton, alignment: .bottom)
            .navigationBarHidden(true)
        }
    }
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            
            WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipped()
                .cornerRadius(50)
                .overlay(RoundedRectangle(cornerRadius: 44)
                            .stroke(Color(.label), lineWidth: 1)
                )
                .shadow(radius: 5)
            
            
            VStack(alignment: .leading, spacing: 4) {
                let email = vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? ""
                Text(email)
                    .font(.system(size: 24, weight: .bold))
                
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 10, height: 10)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
                
            }
            
            Spacer()
            Button {
                shouldShowLogOutOptions.toggle()
            } label: {
                Image(systemName: "lessthan.circle")
                    .font(.system(size: 27, weight: .regular))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal)
                
            }
        }
        .padding()
        .actionSheet(isPresented: $shouldShowLogOutOptions) {
            .init(title: Text("Settings"), message: Text("Would you like to logout?"), buttons: [
                .destructive(Text("Sign Out"), action: {
                    print("handle sign out")
                    vm.handleSignOut()
                }),
                    .cancel()
            ])
        }
        .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut, onDismiss: nil) {
            LoginView(didCompletedLoginInProcess: {
                self.vm.isUserCurrentlyLoggedOut = false
                self.vm.fetchCurrentUser()
                self.vm.fetchRecentMessages()
            })
        }
    }
    
    private var messagesView: some View {
        ScrollView {
            ForEach(vm.recentMessages) { recentMessage in
                VStack {
                    Button {
                        let uid = FirebaseManager.shared.auth.currentUser?.uid == recentMessage.fromId ? recentMessage.toId : recentMessage.fromId
                        
                        self.chatUser = .init(id: uid, uid: uid, email: recentMessage.email, profileImageUrl: recentMessage.profileImageUrl)
                        
                        self.chatLogViewModel.chatUser = self.chatUser
                        self.chatLogViewModel.fetchMessages()
                        self.shouldNavigateToChatLogView.toggle()
                    }
                     label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: recentMessage.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipped()
                                .cornerRadius(64)
                                .overlay(RoundedRectangle(cornerRadius: 64)
                                    .stroke(Color.black, lineWidth: 1 ))
                                .shadow(radius: 5)

                                                        
                            VStack(alignment: .leading, spacing: 8) {
                                Text(recentMessage.username)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(.label))
                                    .multilineTextAlignment(.leading)
                                Text(recentMessage.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(.darkGray))
                                    
                            }
                            Spacer()
                            
                            Text(recentMessage.timeAgo)
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }

                    
                    Divider()
                        .padding(.vertical, 8)
                }.padding(.horizontal)
                
            }.padding(.bottom, 50)
        }
    }
    
    
    @State var shouldShowNewMessageScreen = false
    
    private var newMessageButton: some View {
        Button {
            shouldShowNewMessageScreen.toggle()
                
            
        } label: {
            HStack {
                //Spacer()
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.white))

                
//                Text("+ New Message")
//                    .font(.system(size: 16, weight: .bold))
//                Spacer()
            }
            
            .foregroundColor(.white)
            .padding(.vertical)
            .frame(width: 200, height: 60)
                .background(Color.blue)
                .cornerRadius(50)
                //.padding(.vertical)
                //.shadow(radius: 15)
                //.clipShape(Circle())
                //.padding(.horizontal)
                //Spacer()
                
                
            
        
        }
        .fullScreenCover(isPresented: $shouldShowNewMessageScreen) {
            CreateNewMessageView(didSelectNewUser: {user in
                print(user.email)
                self.shouldNavigateToChatLogView.toggle()
                self.chatUser = user
                self.chatLogViewModel.chatUser = user
                self.chatLogViewModel.fetchMessages()
            })
        }
        
    }
    
@State var chatUser: ChatUser?
}



struct MainMessageView_Preview: PreviewProvider {
    static var previews: some View {
//        MainMessagesView()
//            .preferredColorScheme(.dark)
        
        MainMessagesView()
    }
}

