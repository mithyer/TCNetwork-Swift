//
//  TCHTTPTimerPolicy.swift
//  TCNetwork
//
//  Created by ray on 2017/11/21.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

class TimerPolicy {
    
    required init() {}
    
    enum TimerType {
        case polling, retry, delay
    }
    enum IntervalType {
        case end
        case delay(interval: TimeInterval)
    }
    
    internal var _timer: Timer?
    internal var _isValid: Bool = false
    var isValid: Bool {
        return _isValid
    }
    
    var polledCount: UInt = 0
    var finished: Bool = false
    var timerType: TimerType?
    weak internal var _delegate: AnyObject?
    
    var intervalFunc: ((_ policy: TimerPolicy, _ index: UInt) -> IntervalType)?
    
    class func pollintPolicy(withIntervals intervalFunc: @escaping (_ policy: TimerPolicy, _ index: UInt) -> IntervalType) -> TimerPolicy {
        let policy = self.init()
        policy.intervalFunc = intervalFunc
        policy.timerType = .polling
        return policy
    }
    
    class func delayPolicy(withInterval interval: TimeInterval) -> TimerPolicy? {
        assert(interval > 0)
        guard interval > 0 else {return nil}
        let policy = self.init()
        policy.intervalFunc =  {(_ policy: TimerPolicy, _ index: UInt) -> IntervalType in
            return 0 == index ? .delay(interval: interval) : .end
        }
        policy.timerType = .delay
        return policy
    }
    
    class func retryPolicy(withIntervals intervalFunc: @escaping (_ policy: TimerPolicy, _ index: UInt) -> IntervalType) -> TimerPolicy {
        let policy = self.init()
        policy.intervalFunc = intervalFunc
        policy.timerType = .retry
        return policy
    }
}
