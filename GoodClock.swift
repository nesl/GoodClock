import Foundation

public class Clock {

    public static var refreshRate = 60.0 //clock refresh rate in seconds
    public static var NTP_DELAY_THRESHOLD = 0.200 //maximum allowable NTP response delay in seconds
    
    public class func sync() {
        update()
        Clock.timer?.invalidate()
        Clock.timer = Timer.scheduledTimer(timeInterval: refreshRate, target: self, selector: #selector(Clock.update), userInfo: nil, repeats: true)
    }
    
    public static var now: () -> Double = timeWithDriftCorrection
    
    public static func setDriftCorrection(enabled: Bool) {
        now = enabled ? timeWithDriftCorrection : timeWithoutDriftCorrection
    }
    
    private class func timeWithDriftCorrection() -> Double {
        return (getMonotonicTime() - lastSyncMonotonicTime) * driftFactor + lastSyncSystemTime + offset
    }
    
    private class func timeWithoutDriftCorrection() -> Double {
        return (getMonotonicTime() - lastSyncMonotonicTime) * driftFactor + lastSyncSystemTime + offset
    }
    
    //===============================================================================================
    //===============================================================================================
    //=====BEGIN PRIVATE HELPERS=====================================================================
    //===============================================================================================
    //===============================================================================================
    
    private static var offset = 0.0
    private static var first = true
    private static var lastSyncSystemTime = getCurrentSystemClockTime()
    private static var lastSyncMonotonicTime = getMonotonicTime()
    private static var driftFactor = 1.0
    private static var timer: Timer? = nil
    
    private class func updateSystemClockOffset(offset: Double, systemTime: Double, monotonicTime: Double) {
        let elapsed = (monotonicTime-lastSyncMonotonicTime)
        let systemClockCorrection_ms = abs((monotonicTime-lastSyncMonotonicTime)-(systemTime-lastSyncSystemTime))*1000
        driftFactor = 1.0
        if !first && systemClockCorrection_ms < 10 && elapsed > 5 * 60 {
            //no clock correction, and been drifting for 5+ minutes
            let drift = (offset - Clock.offset) / elapsed //(seconds of drift) per (second)
            if (drift * 1000 * 3600 > 40) {
                //drift is non-negligible, more than 40 ms per hour
                driftFactor = 1 + drift
            }
        }
        
        lastSyncMonotonicTime = monotonicTime
        lastSyncSystemTime = systemTime
        Clock.offset = offset
        first = false
        print("My current system clock offset is: ", offset)
        print("System clock adjusted by", Int(systemClockCorrection_ms), "ms")
        print("Drift rate is", (driftFactor-1) * 1000 * 3600, "ms per hour")
    }
    
    private init() {}
    
    private static var bestOffsetDelays: [(Double, Double, Double, Double)] = []
    
    @objc private class func update()
    {
        bestOffsetDelays = []
        roundsRemaining = 4
        
        if timeservers.count == 0 {
            getTimeservers {
                collectOneRoundOfOffsets()
            }
        } else {
            collectOneRoundOfOffsets()
        }
    }
    
    private class func collectOneRoundOfOffsets() {
        roundsRemaining -= 1
        offsetdelays = []
        roundStarted = getCurrentSystemClockTime()
        for address in timeservers {
            pingTimeserverAndGetOffset(ip: address)
        }
        Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(Clock.roundComplete), userInfo: nil, repeats: false)
    }
    
    private static var roundsRemaining = 4
    private static var roundStarted = 0.0
    @objc private class func roundComplete() {
        if timeservers.count == offsetdelays.count || getCurrentSystemClockTime() - roundStarted > 6 {
            if let best = offsetdelays.min(by: { (o1, o2) -> Bool in
                return o1.1 < o2.1
            }) {
                bestOffsetDelays.append(best)
            }
            if roundsRemaining > 0 {
                collectOneRoundOfOffsets()
            } else {
                var filtered = bestOffsetDelays.filter {
                    $0.1 < NTP_DELAY_THRESHOLD
                }
                filtered.sort { (val1, val2) -> Bool in
                    return val1.0 < val2.0
                }
                if filtered.count > 0 {
                    let the_one_to_use = filtered[filtered.count/2]
                    updateSystemClockOffset(offset: the_one_to_use.0, systemTime: the_one_to_use.2, monotonicTime: the_one_to_use.3)
                }
            }
        } else {
            Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(Clock.roundComplete), userInfo: nil, repeats: false)
        }
    }
    
    
    //===============================================================================================
    //=====BEGIN Timing Functions Code===============================================================
    //===============================================================================================
    
    
    private class func getCurrentSystemClockTime() -> TimeInterval {
        var current = timeval()
        let systemTimeError = gettimeofday(&current, nil) != 0
        assert(!systemTimeError, "system time unavailable")
        
        return Double(current.tv_sec) + Double(current.tv_usec) / 1_000_000
    }
    
    //returns system uptime in us
    private static func getMonotonicTime() -> TimeInterval {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var size = MemoryLayout<timeval>.stride
        var bootTime = timeval()
        
        let bootTimeError = sysctl(&mib, u_int(mib.count), &bootTime, &size, nil, 0) != 0
        assert(!bootTimeError, "system clock error: kernel boot time unavailable")
        
        let now = getCurrentSystemClockTime()
        let uptime = Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000
        assert(now >= uptime, "inconsistent clock state: system time precedes boot time")
        
        return now - uptime
    }
    
    
    //===============================================================================================
    //=====BEGIN Timeserver Code=====================================================================
    //===============================================================================================
    
    private static var timeservers: [String] = []
    
    private class func getTimeservers(host: String = "time.apple.com", next: () -> Void){
        let host = CFHostCreateWithName(nil,host as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray? {
            for case let theAddress as NSData in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let numAddress = String(cString: hostname)
                    var sin = sockaddr_in()
                    if numAddress.withCString({ (cstring)  in
                        inet_pton(AF_INET, cstring, &sin.sin_addr)
                    }) == 1 {
                        //It's an ipv4 address
                        timeservers.append(numAddress)
                    }
                }
            }
        }
        print("NTP timeservers:", timeservers)
        next()
    }
    
    //===============================================================================================
    //=====BEGIN NTP Socket Code=====================================================================
    //===============================================================================================
    
    private static var offsetdelays: [(Double, Double, Double, Double)] = []
    private class func addOffsetAndDelay(offset: Double, delay: Double) {
        offsetdelays.append((offset, delay, Clock.getCurrentSystemClockTime(), Clock.getMonotonicTime()))
    }
    
    private static var mapIPtoRunLoop: [String:CFRunLoopSource] = [:]
    private class func cleanUpRunLoop(ip: String) {
        if let runLoop = mapIPtoRunLoop.removeValue(forKey: ip) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoop, CFRunLoopMode.commonModes)
        }
    }
    
    private class func pingTimeserverAndGetOffset(ip: String) {
        let socketAddressData = getAddressData(address: ip)
        
        let callback: CFSocketCallBack = { socket, callbackType, address, data, info in
            if callbackType == .writeCallBack {
                print("Pushing NTP Packet...")
                CFSocketSendData(socket, nil, Clock.getNTPpacketData(), 6.0)
                return
            }
            let destinationTime = Clock.getCurrentSystemClockTime()
            CFSocketInvalidate(socket)
            if let addy = address {
                
                Clock.cleanUpRunLoop(ip: Clock.convertDataToIPAddr(data: addy))
            }
            let data = unsafeBitCast(data, to: CFData.self) as Data
            
            let originTime = Clock.readTimeFromNTPPacket(data: data, index: 24)
            let receiveTime = Clock.readTimeFromNTPPacket(data: data, index: 32)
            let transmitTime = Clock.readTimeFromNTPPacket(data: data, index: 40)
            
            let offset = ((receiveTime-originTime) + (transmitTime - destinationTime)) / 2
            let delay = (destinationTime - originTime) - (transmitTime - receiveTime)
            
            Clock.addOffsetAndDelay(offset: offset, delay: delay)
            
            print("Received NTP Packet: offset: ",offset, "    delay :", Int(delay*1000))
        }
        
        let types = CFSocketCallBackType.dataCallBack.rawValue | CFSocketCallBackType.writeCallBack.rawValue
        let socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_DGRAM, IPPROTO_UDP, types, callback, nil)
        let runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0)
        mapIPtoRunLoop[ip] = runLoopSource!
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, CFRunLoopMode.commonModes)
        CFSocketConnectToAddress(socket, socketAddressData, 6.0)
    }
    
    //===============================================================================================
    //=====BEGIN NTP Socket HELPERS==================================================================
    //===============================================================================================
    
    private class func getAddressData(address: String) -> CFData {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout.size(ofValue: addr))
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr(address)
        addr.sin_port = in_port_t(123).bigEndian
        return Data(bytes: &addr, count: MemoryLayout<sockaddr_in>.size) as CFData
    }
    
    private class func getNTPpacketData() -> CFData {
        //generate NTP packet
        var ntpPacket: [UInt8] = Array(repeating: 0, count: 40)
        //set version and mode
        ntpPacket[0] = 3 | (3 << 3)
        //set requestTime
        var ntpData = Data(ntpPacket)
        let time = getCurrentSystemClockTime()
        let integer = UInt32(time + 2208988800.0)
        let decimal = modf(time).1 * 4294967296.0 // 2 ^ 32
        let val = UInt64(integer) << 32 | UInt64(decimal)
        var num_data = val.bigEndian
        ntpData.append(UnsafeBufferPointer(start: &num_data, count: 1))
        return ntpData as CFData
    }
    
    private class func readTimeFromNTPPacket(data: Data, index: Int) -> Double {
        let end = index + 8
        
        let val: UInt64 = data.subdata(in: index ..< end).withUnsafeBytes { (rawPointer) in
            rawPointer.bindMemory(to: UInt64.self).baseAddress!.pointee
        }
        
        let time = val.bigEndian
        let integer = Double(time >> 32)
        let decimal = Double(time & 0xffffffff) / 4294967296.0
        return integer - 2208988800.0 + decimal
    }
    
    private class func convertDataToIPAddr(data: CFData) -> String {
        var address = sockaddr_in()
        (data as NSData).getBytes(&address, length: MemoryLayout<sockaddr_in>.size)
        return String(cString: inet_ntoa(address.sin_addr))
    }
}
