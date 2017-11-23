//
//  TimerPolicy+Request.swift
//  TCNetwork
//
//  Created by ray on 2017/11/23.
//  Copyright © 2017年 ray. All rights reserved.
//

import Foundation

protocol TimerDelegate {
    func timerRequest(forPolicy policy: TimerPolicy) -> Bool
    func requestResponded(isValid: Bool, clean: Bool)
}

extension TimerPolicy {
    
    var delegate: TimerDelegate? {
        get {
            return _delegate as? TimerDelegate
        }
        set(new) {
            _delegate = new as AnyObject
        }
    }
    
    // stop timer, cancel executing request, only called by request.
    func invalidate() {
        if !_isValid {
            return
        }
        _timer?.invalidate()
        _timer = nil
        self.complete(finish: false)
    }
    
    /**
     @brief    go to next polling, called by request
     
     @return YES: entry polling, NO: finished
     */
    func forward() -> Bool {
        if !self.isValid {
            return false
        }
        let interval = self.intervalFunc!(self, self.polledCount)
        self.polledCount = self.polledCount + 1
        switch interval {
        case .delay(interval: let interval):
            if interval > 0 {
                self.fireTimer(withInterval: interval)
            } else {
                self.fireRequest()
            }
            return true
        case .end:
            self.complete(finish: true)
            return false
        }
    }
    
    private func fireTimer(withInterval interval: TimeInterval) {
        _timer = Timer.init(timeInterval: interval, target: self, selector: #selector(TimerPolicy.fireRequest), userInfo: nil, repeats: false)
        RunLoop.main.add(_timer!, forMode: .commonModes)
    }
    
    @objc private func fireRequest(timer: Timer? = nil) {
        _timer = nil
        if nil == self.delegate || self.delegate!.timerRequest(forPolicy: self) {
            self.complete(finish: false)
            self.delegate!.requestResponded(isValid: false, clean: true)
        }
    }
    
    var canForward: Bool {
        guard let intervalFunc = self.intervalFunc else {
            self.complete(finish: true)
            return false
        }
        switch intervalFunc(self, self.polledCount) {
        case .end:
            self.complete(finish: true)
            return false
        default:
            _isValid = true
        }
        return true
    }
    
    var isTicking: Bool {
        return false
    }
    
    var needStartTimer: Bool {
        return self.polledCount < 1 && !self.isValid && self.canForward
    }
    
    func checkForwardForRequest(success: Bool) -> Bool {
        if self.timerType == .retry && self.isValid && success {
            self.complete(finish: true)
            return false
        }
        return self.canForward
    }
    
    private func complete(finish: Bool) {
        self.intervalFunc = nil
        _isValid = false
        self.finished = finish
    }
}
