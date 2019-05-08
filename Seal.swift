//
//  Seal.swift
//  PeevedPenguins
//
//  Created by Hind Al-rammah on 5/28/15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

import Foundation
class Seal: CCSprite {
  
   func didLoadFromCCB() {
       self.physicsBody.collisionType! = "seal"
    }
}
