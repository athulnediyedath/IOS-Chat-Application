//
//  ChatMessage.swift
//  CsereH
//
//  Created by Himanshu Vinchurkar on 07/06/23.
//

import Foundation
import FirebaseFirestoreSwift

struct ChatMessage: Codable, Identifiable {
    
    
    @DocumentID var id: String?
    let fromId, toId, text: String
    let timestamp: Date
    
}
