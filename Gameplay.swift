//
//  Gameplay.swift
//  PeevedPenguins
//
//  Created by Hind Al-rammah on 5/29/15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

import Foundation

//import "CCPhysics+ObjectiveChipmunk.h"

class Gameplay: CCNode, CCPhysicsCollisionDelegate {
    // Constants
    let MIN_SPEED: Float = 5;
    
    // SB Code Connections
    var _physicsNode: CCPhysicsNode?
    var _catapultArm: CCNode?
    var _levelNode: CCNode?
    var _contentNode: CCNode?
    var _pullbackNode: CCNode?
    var _mouseJointNode: CCNode?
    
    var _mouseJoint: CCPhysicsJoint?
    var _currentPenguin: Penguin?
    var _penguinCatapultJoint: CCPhysicsJoint?
    var _followPenguin: CCAction?
    
    func didLoadFromCCB() {
        self.userInteractionEnabled = true
        //This will load level1 and add it as a child to the levelNode.
        var level: CCNode = CCBReader.load("Levels/Level1")
        _levelNode!.addChild(level)
        
        _physicsNode?.collisionDelegate = self;
        
        //A property called collisionMask allows us to choose with which objects our physics object will collide. If we set the collisionMask to an empty array, our object won't collide with any other objects in the game
        _pullbackNode!.physicsBody.collisionMask = []
        _mouseJointNode!.physicsBody.collisionMask = []
      
       // _physicsNode!.debugDraw = true
    }
   
    
    override func touchBegan(touch: CCTouch, withEvent event: CCTouchEvent) {
        var touchLocation: CGPoint = touch.locationInNode(_contentNode)
        self.handleTouchBegan(touchLocation)
    }
    override func touchMoved(touch: CCTouch, withEvent event: CCTouchEvent) {
        // whenever touches move, update the position of the mouseJointNode to the touch position
        var touchLocation: CGPoint = touch.locationInNode(_contentNode)
        _mouseJointNode!.position = touchLocation
    }
    
     // when touches end, meaning the user releases their finger, release the catapult
    override func touchEnded(touch: CCTouch, withEvent event: CCTouchEvent) {
        self.releaseCatapult()
    }
    
    // when touches are cancelled, meaning the user drags their finger off the screen or onto something else, release the catapult
    override func touchCancelled(touch: CCTouch, withEvent event: CCTouchEvent) {
        self.releaseCatapult()
    }
    
    func handleTouchBegan(touchLocation: CGPoint) {
        
        // start catapult dragging when a touch inside of the catapult arm occurs
        if (CGRectContainsPoint(_catapultArm!.boundingBox(), touchLocation))
        {
            // Move mouse joint position to touch location
            _mouseJointNode!.position = touchLocation
            
            // Create sprint joint between catapult arm and mouseJointNode
            _mouseJoint = CCPhysicsJoint.connectedSpringJointWithBodyA(_mouseJointNode!.physicsBody, bodyB:_catapultArm!.physicsBody,
                anchorA:ccp(0, 0),
                anchorB:ccp(34, 138),
                restLength:0.0,
                stiffness:3000,
                damping:150)
            
            // create a penguin from the ccb-file
           _currentPenguin = CCBReader.load("Penguin") as! Penguin?
            // Position on Catapult,initially position it on the scoop. 34,138 is the position in the node space of the _catapultArm
            //// transform the world position to the node space to which the penguin will be added (_physicsNode)
            var penguinPosition: CGPoint = _catapultArm!.convertToWorldSpace(ccp(34,138))
            _currentPenguin!.position = _physicsNode!.convertToWorldSpace(penguinPosition)
            
            // add it to the physics world
            _physicsNode?.addChild(_currentPenguin)
            // we don't want the penguin to rotate in the scoop
            _currentPenguin?.physicsBody.allowsRotation = false
            
            // Setup Joint, keep penguin attached to catapult while pulling back catapult arm
            _penguinCatapultJoint = CCPhysicsJoint.connectedPivotJointWithBodyA(_currentPenguin!.physicsBody,
                bodyB:_catapultArm!.physicsBody,
                anchorA:_currentPenguin!.anchorPointInPoints)
            
        }
    }
    
    func releaseCatapult() {
        if _mouseJoint != nil {
           // releases the joint and lets the catapult snap back
            _mouseJoint?.invalidate()
            _mouseJoint = nil;
            
         // releases the joint and lets the penguin fly
            _penguinCatapultJoint?.invalidate()
            _penguinCatapultJoint = nil
            
            _currentPenguin?.physicsBody.allowsRotation = true;
            
        // follow the flying penguin
            _followPenguin = CCActionFollow.actionWithTarget(_currentPenguin, worldBoundary:self.boundingBox()) as! CCAction!
            _contentNode!.runAction(_followPenguin)
            _currentPenguin!.launched = true;
            
        }
        
        
    }
    // Collision Handlers
    //The parameter name "seal" in this method is derived from the collisionType "seal" The second parameter "wildcard" means any arbitrary object.
    // this delegate method is called when an object with the collisionType "seal" collides with any other object
   
    func ccPhysicsCollisionPostSolve(pair: CCPhysicsCollisionPair!, seal nodeA: CCNode!, wildcard nodeB: CCNode!) {
        
        var energy: CGFloat = pair.totalKineticEnergy
        
        // Kill seal if high impact
        if (energy > 100000) {
            _physicsNode!.space.addPostStepBlock({
                self.sealRemoved(nodeA)
                }, key:nodeA)
        }
        
        
    }

    // Seal Action
    func sealRemoved(seal: CCNode) {
        // Setup Particle
        var explosion: CCParticleSystem = CCBReader.load("SealExplosion") as! CCParticleSystem
        
        explosion.autoRemoveOnFinish = true;
        
        explosion.position = seal.position;
        
        seal.parent.addChild(explosion);
        
        seal.removeFromParent()
    }
    
    
    
    //First we reset the reference to the _currentPenguin, because once an attempt is completed we consider none of the penguins as current one. Then we stop the scrolling action in the second line. Finally we create a new action to scroll back to the catapult.
    func nextAttempt() {
        _currentPenguin = nil;
        _contentNode!.stopAction(_followPenguin);
        
        var actionMoveTo: CCAction = CCActionMoveTo.actionWithDuration(1, position:ccp(0, 0)) as! CCAction;
        _contentNode!.runAction(actionMoveTo);
    }
    
    // Update
    override func update(delta: CCTime) {
        
        if (_currentPenguin?.launched == true) {
            
            // If speed below threshold then assume attempt over
            //We check whether the speed is below our defined limit. Therefore we use the ccpLength function that calculates the square length of our velocity (basically the x- and y-component of the speed combined).
            //Further we check if the penguin has exited the level through the left or right boundary. If anything of this happens, we call the nextAttempt method and return immediately (to avoid that nextAttempt is called multiple times)
            if Float(ccpLength(_currentPenguin!.physicsBody.velocity)) < MIN_SPEED {
                self.nextAttempt();
                return;
            }
            
            let xMin = _currentPenguin!.boundingBox().origin.x;
            
            if (xMin < self.boundingBox().origin.x) {
                self.nextAttempt();
                return;
            }
            
            let xMax = xMin + _currentPenguin!.boundingBox().size.width;
            
            if (xMax > (self.boundingBox().origin.x + self.boundingBox().size.width)) {
                self.nextAttempt();
                return;
            }
        }
    }
    
    func retry() {
        
        var gameplayScene: CCScene = CCBReader.loadAsScene("Gameplay")
        CCDirector.sharedDirector().replaceScene(gameplayScene);
    }
    
   
}
