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
    
    private var _timer: Timer?
    private var _isValid: Bool = false
    var isValid: Bool {
        return _isValid
    }
    
    var polledCount: UInt = 0
    var finished: Bool = false
    var timerType: TimerType?
    
    var intervalFunc: ((_ policy: TimerPolicy, _ index: UInt) -> TimeInterval)?
    
    class func pollintPolicy(withIntervals intervalFunc: @escaping (_ policy: TimerPolicy, _ index: UInt) -> TimeInterval) -> TimerPolicy {
        let policy = self.init()
        policy.intervalFunc = intervalFunc
        policy.timerType = .polling
        return policy
    }
    
    static let timerIntervalEnd: Double = -1
    class func delayPolicy(withInterval interval: TimeInterval) -> TimerPolicy? {
        assert(interval > 0)
        guard interval > 0 else {return nil}
        let policy = self.init()
        policy.intervalFunc =  {(_ policy: TimerPolicy, _ index: UInt) -> TimeInterval in
            return 0 == index ? interval : timerIntervalEnd
        }
        policy.timerType = .delay
        return policy
    }
    
    class func retryPolicy(withIntervals intervalFunc: @escaping (_ policy: TimerPolicy, _ index: UInt) -> TimeInterval) -> TimerPolicy {
        let policy = self.init()
        policy.intervalFunc = intervalFunc
        policy.timerType = .retry
        return policy
    }
}
