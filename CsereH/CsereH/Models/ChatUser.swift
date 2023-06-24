//
//  ChatUser.swift
//  CsereH
//
//  Created by Himanshu Vinchurkar on 03/06/23.
//

import Foundation
import FirebaseFirestoreSwift



struct ChatUser: Codable, Identifiable {
    
    @DocumentID var id: String?
    
    //var id: String{uid}
    
    let uid, email, profileImageUrl: String
    
//    init(data: [String:Any]) {
//        self.uid = data["uid"] as? String ?? ""
//        self.email = data["email"] as? String ?? ""
//        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
//
//    }
    
    
}

