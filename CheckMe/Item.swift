//
//  Item.swift
//  CheckMe
//
//  Created by Dev Patel on 2026-05-16.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
