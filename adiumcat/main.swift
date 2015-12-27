//
//  main.swift
//  adiumcat
//
//  Created by Antonio Malara on 16/08/14.
//  Copyright (c) 2014 Antonio Malara. All rights reserved.
//

import Foundation

let adiumBasePath = NSURL(fileURLWithPath: "~/Library/Application Support/Adium 2.0/Users/Default/", isDirectory: true)

let fm = NSFileManager.defaultManager()

let isodateFormatter = NSDateFormatter()
isodateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"
isodateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
isodateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)

func accountDirs() -> [NSURL]? {
    let logsPath = adiumBasePath.URLByAppendingPathComponent("Logs")
    return try? fm.contentsOfDirectoryAtURL(logsPath, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles)
}

func allBuddies() -> [String] {
    guard let accs = accountDirs() else {
        return [String]()
    }
    
    do {
        return try accs
            .flatMap { try fm.contentsOfDirectoryAtURL($0, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles) }
            .map { $0.lastPathComponent! }
            .filter { $0 != nil }
    }
    catch {
        return [String]()
    }
}

func buddyDir(buddyName : String) -> NSURL? {
    guard let accs = accountDirs() else {
        return nil
    }
    
    do {
        let err : NSErrorPointer = nil
        
        return try accs
            .flatMap { try fm.contentsOfDirectoryAtURL($0, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles) }
            .map { $0.URLByAppendingPathComponent(buddyName) }
            .filter({ $0.checkResourceIsReachableAndReturnError(err) })
            .first
    }
    catch {
        return nil
    }
}

class LogEvent {
    var alias  : String
    var sender : String
    var time   : NSDate

    init(
        alias  : String,
        sender : String,
        time   : NSDate
    )
    {
        self.alias  = alias
        self.sender = sender
        self.time   = time
    }
    
    func toString() -> String {
        return "LogEvent \(alias) \(sender) \(time)"
    }
}

class StatusEvent : LogEvent {
    var type : String
    
    init(
        type   : String,
        alias  : String,
        sender : String,
        time   : NSDate
    )
    {
        self.type = type
        super.init(alias: alias, sender: sender, time: time)
    }
    
    override func toString() -> String  {
        return "[\(self.time)] *** \(self.alias) \(self.type)"
    }
}

class MessageEvent : LogEvent {
    var message : String = ""
    
    override init(
        alias  : String,
        sender : String,
        time   : NSDate
    )
    {
        super.init(alias: alias, sender: sender, time: time)
    }
    
    override func toString() -> String  {
        return "[\(self.time)] <\(self.alias)> \(self.message)"
    }
}

class LogCollectorDelegate : NSObject, NSXMLParserDelegate {
    var me : String?
    var events = [LogEvent]()
    var currentMessage : MessageEvent?
    
    func parser(
        parser: NSXMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attrs: [String : String]
    )
    {
        if elementName == "chat" {
            self.me = attrs["account"]
        }

        if elementName == "status" {
            if let t = attrs["type"], a = attrs["alias"], s = attrs["sender"], ti = attrs["time"] {
                let time = isodateFormatter.dateFromString(ti)
                let item = StatusEvent(
                    type:   t,
                    alias:  a,
                    sender: s,
                    time:   time! // FIXME
                )
                self.events.append(item)
            }
        }
        
        if elementName == "message" {
            if let a = attrs["alias"], s = attrs["sender"], ti = attrs["time"] {
                let time = isodateFormatter.dateFromString(ti)
                let item = MessageEvent(
                    alias:  a,
                    sender: s,
                    time:   time!
                )
                    
                self.events.append(item)
                self.currentMessage = item
            }
        }
    }
    
    func parser(
        parser: NSXMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    )
    {
        if elementName == "message" {
            currentMessage = nil
        }
    }

    func parser(parser: NSXMLParser, foundCharacters string: String) {
        if let message = self.currentMessage {
            message.message.appendContentsOf(string)
        }
    }
}

func loadAllConversations(buddyDir : NSURL) -> [LogEvent] {
    guard let convs = try? fm.contentsOfDirectoryAtURL(buddyDir, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles) else {
        return [LogEvent]()
    }

    var allXmls = [NSURL]()
    
    for dayDir in convs {
        let fileName = dayDir.absoluteString.stringByReplacingOccurrencesOfString(
            ".chatlog",
            withString: ".xml",
            options: NSStringCompareOptions.BackwardsSearch,
            range: nil
        )
        allXmls.append(NSURL(fileURLWithPath: fileName))
    }

    let delegate = LogCollectorDelegate()
    for file in allXmls {
        let parser = NSXMLParser(contentsOfURL: file)
        parser!.delegate = delegate
        parser!.parse()
    }

    return delegate.events
}

func printAllBuddies() {
    for buddy in allBuddies() {
        print(buddy)
    }
    exit(0)
}

func printBuddy(name : String) {
    let dir = buddyDir(name)
    if (dir != nil) {
        let events = loadAllConversations(dir!)
        for e in events {
            print(e.toString())
        }
        exit(0)
    } else {
        print("logs for \"\(name)\" not found!")
        exit(2)
    }
}

func usage() {
    let program = Process.arguments[0]
    print("usage: \(program) [buddy_name]")
    exit(1)
}


func main() {
    let argc = Process.arguments.count

    if argc == 1 {
        printAllBuddies()
    } else if argc == 2 {
        printBuddy(Process.arguments[1])
    } else {
        usage()
    }
}

main()
