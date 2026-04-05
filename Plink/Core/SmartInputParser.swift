import Foundation
import NaturalLanguage

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SmartInputResult {
    var title: String
    var desc: String = ""
    var dueDate: Date?
    var hasDueTime: Bool = false
    var priority: Priority
    var groupName: String?        // nil = no group prefix detected
    var blockingStatus: BlockingStatus? = nil  // nil = not set
}

// MARK: – Engine availability

enum SmartEngine {
    case foundationModels   // macOS 26+, Apple Intelligence enabled
    case nlTagger           // macOS 14+, always available

    static var current: SmartEngine {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if SystemLanguageModel.default.isAvailable { return .foundationModels }
        }
        #endif
        return .nlTagger
    }

    var label: String {
        switch self {
        case .foundationModels: return "Apple Intelligence"
        case .nlTagger:         return "On-device NLP"
        }
    }
}

// MARK: – Parser

enum SmartInputParser {

    static func parse(_ input: String) async -> SmartInputResult {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), SystemLanguageModel.default.isAvailable {
            if let result = await parseWithFoundationModels(input) { return result }
        }
        #endif
        return parseWithNLTagger(input)
    }

    // MARK: – FoundationModels path

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    @Generable
    struct LLMTaskResult {
        @Guide(description: "Priority level. Must be one of: none, low, medium, high.")
        var priority: String
    }

    @available(macOS 26, *)
    private static func parseWithFoundationModels(_ input: String) async -> SmartInputResult? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }

        let session = LanguageModelSession()

        let prompt = """
        Analyse the following task input and extract only the priority level. \
        Keep all text in the same language as the input — do not translate.
        Input: \(input)
        """

        do {
            let response = try await session.respond(to: prompt, generating: LLMTaskResult.self)
            let result = response.content
            var text = input
            let groupName = extractGroupPrefix(from: &text)
            let priority: Priority = {
                switch result.priority.lowercased() {
                case "high":   return .high
                case "medium": return .medium
                case "low":    return .low
                default:       return .none
                }
            }()
            var dueDate = extractDate(from: &text)
            let timeComponents = extractTime(from: &text)
            if let tc = timeComponents {
                let base = dueDate ?? Calendar.current.startOfDay(for: Date())
                dueDate = Calendar.current.date(bySettingHour: tc.hour, minute: tc.minute, second: 0, of: base)
            }
            let title = buildTitle(from: text)
            var parsed = SmartInputResult(title: title, dueDate: dueDate, priority: priority, groupName: groupName)
            parsed.hasDueTime = timeComponents != nil
            return parsed
        } catch {
            return nil
        }
    }
    #endif

    // MARK: – Token parser
    //
    // Syntax: <title text> <tokens in any order>
    // Tokens:
    //   @<date>    e.g. @tomorrow @today @10.05. @monday
    //   @@<time>   e.g. @@10:00  @@14:30
    //   #<group>   e.g. #Peter Park    (extends to next token)
    //   !<flag>    Priority:  !h(igh)  !m(edium)  !l(ow)
    //              Blocking:  !b(locked — ich bin blockiert)  !x (ich blockiere)
    //
    // Title = everything before the first token symbol.
    // Each token's value extends to the next token symbol (@ # !) or end.
    // Note: @@ is a distinct token; the scanner checks for it before @.
    // Unknown values are silently ignored — tokens are always stripped from title.

    static func parseWithTokens(_ input: String) -> SmartInputResult {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenSyms: Set<Character> = ["@", "#", "!"]

        // Title = text before the first token symbol
        let firstTok = text.firstIndex(where: { tokenSyms.contains($0) }) ?? text.endIndex
        let titleRaw = String(text[..<firstTok]).trimmingCharacters(in: .whitespacesAndNewlines)
        let title = titleRaw.isEmpty ? titleRaw : titleRaw.prefix(1).uppercased() + titleRaw.dropFirst()

        var groupName: String? = nil
        var priority: Priority = .none
        var blockingStatus: BlockingStatus? = nil
        var dueDate: Date? = nil
        var hasDueTime = false

        var i = firstTok
        while i < text.endIndex {
            let ch = text[i]
            guard tokenSyms.contains(ch) else { i = text.index(after: i); continue }

            let afterSym = text.index(after: i)

            // Check for @@ (time token)
            if ch == "@", afterSym < text.endIndex, text[afterSym] == "@" {
                let valueStart = text.index(after: afterSym)
                let valueEnd = nextTokenIndex(from: valueStart, in: text)
                var expr = String(text[valueStart..<valueEnd]).trimmingCharacters(in: .whitespaces)
                if let tc = extractTime(from: &expr) {
                    if dueDate == nil { dueDate = Calendar.current.startOfDay(for: Date()) }
                    dueDate = Calendar.current.date(bySettingHour: tc.hour, minute: tc.minute, second: 0, of: dueDate!)
                    hasDueTime = true
                }
                i = valueEnd
                continue
            }

            // Single @ (date token)
            if ch == "@" {
                let valueEnd = nextTokenIndex(from: afterSym, in: text)
                var expr = String(text[afterSym..<valueEnd]).trimmingCharacters(in: .whitespaces)
                if let d = extractDate(from: &expr) { dueDate = d }
                i = valueEnd
                continue
            }

            // # (group token)
            if ch == "#" {
                let valueEnd = nextTokenIndex(from: afterSym, in: text)
                let name = String(text[afterSym..<valueEnd]).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { groupName = name }
                i = valueEnd
                continue
            }

            // ! (flag token: priority or blocking) — first word only
            // Primary (language-neutral): !h !m !l !b !x
            // EN aliases: !high !medium !low !blocked !blocking
            // DE aliases: !hoch !mittel !niedrig !blockiert !blockiere
            if ch == "!" {
                let valueEnd = nextTokenIndex(from: afterSym, in: text)
                let kw = String(text[afterSym..<valueEnd])
                    .prefix(while: { $0 != " " }).lowercased()
                switch kw {
                case "h", "high",    "hoch":                            priority = .high
                case "m", "medium",  "mittel":                          priority = .medium
                case "l", "low",     "niedrig":                         priority = .low
                case "b", "blocked", "blockiert":                       blockingStatus = .blocked
                case "x", "blocking","blockiere", "blocke":             blockingStatus = .blocking
                default: break  // unknown value — silently ignored
                }
                i = valueEnd
                continue
            }

            i = text.index(after: i)
        }

        var result = SmartInputResult(title: title, dueDate: dueDate, priority: priority, groupName: groupName)
        result.hasDueTime = hasDueTime
        result.blockingStatus = blockingStatus
        return result
    }

    private static func nextTokenIndex(from start: String.Index, in text: String) -> String.Index {
        let syms: Set<Character> = ["@", "#", "!"]
        return text[start...].firstIndex(where: { syms.contains($0) }) ?? text.endIndex
    }

    // MARK: – NLTagger path (always available)

    static func parseWithNLTagger(_ input: String) -> SmartInputResult {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupName = extractGroupPrefix(from: &text)
        let priority  = extractPriority(from: &text)
        var dueDate   = extractDate(from: &text)
        let timeComponents = extractTime(from: &text)
        if let tc = timeComponents {
            let base = dueDate ?? Calendar.current.startOfDay(for: Date())
            dueDate = Calendar.current.date(bySettingHour: tc.hour, minute: tc.minute, second: 0, of: base)
        }
        let title = buildTitle(from: text)
        var result = SmartInputResult(title: title, dueDate: dueDate, priority: priority, groupName: groupName)
        result.hasDueTime = timeComponents != nil
        return result
    }

    // MARK: – Group prefix extraction
    // Matches "GroupName: rest of input" at the very start.

    private static func extractGroupPrefix(from text: inout String) -> String? {
        // Pattern: word characters (and spaces) followed by colon+space at start
        let pattern = #"^([^:]{1,40}):\s+"#
        guard let match = firstMatch(pattern, in: text),
              let range = Range(match.range, in: text),
              let nameRange = Range(match.range(at: 1), in: text) else { return nil }
        let name = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        text.removeSubrange(range)
        return name
    }

    // MARK: – Title builder
    // The full remaining text (after extracting group/date/priority) becomes the title.
    // Filler phrases at the start are stripped but the rest is kept verbatim.

    private static func buildTitle(from text: String) -> String {
        var result = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let fillers = ["i need to ","i have to ","i must ","i should ","i want to ",
                       "ich muss ","ich soll ","ich möchte ","ich will ",
                       "please ","bitte ","remind me to ","don't forget to "]
        for f in fillers {
            if result.lowercased().hasPrefix(f) { result = String(result.dropFirst(f.count)); break }
        }
        result = result.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
        guard let first = result.first else { return result }
        return first.uppercased() + result.dropFirst()
    }

    // MARK: – Date + time extraction

    private static func extractDate(from text: inout String) -> Date? {
        if let result = extractRelativeDate(from: &text) { return result }
        return extractDetectorDate(from: &text)
    }

    /// Extracts a clock time from the text (e.g. "um 10:00 Uhr", "at 3pm", "15:30").
    /// Returns hour/minute components and removes the matched span from text.
    static func extractTime(from text: inout String) -> (hour: Int, minute: Int)? {
        let lower = text.lowercased()

        // Pattern 1: "um HH:MM Uhr" or "um H:MM Uhr"
        // Pattern 2: "at H:MM am/pm" or "at Hpm" / "at H am"
        // Pattern 3: standalone HH:MM (24h)
        // Pattern 4: "Num Uhr" e.g. "10 Uhr", "10:30 Uhr"
        let patterns: [String] = [
            #"(?:um\s+)(\d{1,2}):(\d{2})\s*uhr"#,
            #"(?:at\s+)(\d{1,2}):(\d{2})\s*(am|pm)"#,
            #"(?:at\s+)(\d{1,2})\s*(am|pm)"#,
            #"(\d{1,2}):(\d{2})\s*uhr"#,
            #"\b(\d{1,2})\s+uhr\b"#,
            #"\b(\d{1,2}):(\d{2})\b"#,
        ]

        for pattern in patterns {
            guard let match = firstMatch(pattern, in: lower),
                  let fullRange = Range(match.range, in: lower) else { continue }

            let g1 = groupString(match, group: 1, in: lower).flatMap(Int.init) ?? 0
            let g2 = groupString(match, group: 2, in: lower).flatMap(Int.init)
            let ampm = groupString(match, group: match.numberOfRanges > 3 ? 3 : 2, in: lower) ?? ""

            var hour = g1
            let minute = g2 ?? 0
            if ampm == "pm" && hour < 12 { hour += 12 }
            if ampm == "am" && hour == 12 { hour = 0 }

            guard hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 else { continue }
            text.removeSubrange(fullRange)
            text = text.trimmingCharacters(in: .init(charactersIn: " ,"))
            return (hour, minute)
        }
        return nil
    }

    private static func extractRelativeDate(from text: inout String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        let lower = text.lowercased()

        let namedDays: [(pattern: String, offset: Int)] = [
            (#"(?<!\w)(übermorgen|day after tomorrow)(?!\w)"#, 2),
            (#"(?<!\w)(morgen|tomorrow)(?!\w)"#,               1),
            (#"(?<!\w)(heute|today)(?!\w)"#,                   0),
        ]
        for (pattern, offset) in namedDays {
            if let match = firstMatch(pattern, in: lower), let range = Range(match.range, in: lower) {
                let date = cal.date(byAdding: .day, value: offset, to: now)!
                text.removeSubrange(range)
                let trimmed = text.trimmingCharacters(in: .init(charactersIn: ", ").union(.whitespaces))
                text = trimmed
                return cal.startOfDay(for: date)
            }
        }

        let nextPeriodPatterns: [(String, DateComponents)] = [
            (#"(?<!\w)(nächste[nr]?\s+woche|next\s+week)(?!\w)"#,  DateComponents(day: 7)),
            (#"(?<!\w)(nächsten?\s+monat|next\s+month)(?!\w)"#,    DateComponents(month: 1)),
        ]
        for (pattern, comps) in nextPeriodPatterns {
            if let match = firstMatch(pattern, in: lower), let range = Range(match.range, in: lower) {
                if let date = cal.date(byAdding: comps, to: now) {
                    text.removeSubrange(range)
                    return cal.startOfDay(for: date)
                }
            }
        }

        let relativePattern = #"(?:in\s+)?(\d+|one|two|three|four|five|six|seven|eight|nine|ten|a|einer?|zwei|drei|vier|sechs|sieben|acht|neun|zehn|fuenf|funf)\s+(days?|tag|tage|tagen|weeks?|woche|wochen|months?|monat|monate|monaten)(?:\s+from\s+now)?"#
        if let match = firstMatch(relativePattern, in: lower), let range = Range(match.range, in: lower) {
            let numberStr = groupString(match, group: 1, in: lower) ?? ""
            let unit      = groupString(match, group: 2, in: lower) ?? ""
            let n = wordToInt(numberStr) ?? Int(numberStr) ?? 1
            var comps = DateComponents()
            if unit.hasPrefix("day") || unit.hasPrefix("tag")    { comps.day   = n }
            if unit.hasPrefix("week") || unit.hasPrefix("woch")  { comps.day   = n * 7 }
            if unit.hasPrefix("month") || unit.hasPrefix("mona") { comps.month = n }
            if let date = cal.date(byAdding: comps, to: now) {
                text.removeSubrange(range)
                return cal.startOfDay(for: date)
            }
        }

        let weekdayRelPattern = #"(\w+day)\s+in\s+(\d+|one|two|three|four|five|six|seven)\s+weeks?"#
        if let match = firstMatch(weekdayRelPattern, in: lower), let range = Range(match.range, in: lower) {
            let dayName   = groupString(match, group: 1, in: lower) ?? ""
            let numberStr = groupString(match, group: 2, in: lower) ?? ""
            let n = wordToInt(numberStr) ?? Int(numberStr) ?? 1
            if let weekday = weekdayNumber(dayName),
               let base = cal.date(byAdding: .weekOfYear, value: n, to: now),
               let date = nextWeekday(weekday, from: base, calendar: cal) {
                text.removeSubrange(range)
                return cal.startOfDay(for: date)
            }
        }

        let nextPattern = #"(next|this)\s+(\w+day)"#
        if let match = firstMatch(nextPattern, in: lower), let range = Range(match.range, in: lower) {
            let modifier = groupString(match, group: 1, in: lower) ?? "next"
            let dayName  = groupString(match, group: 2, in: lower) ?? ""
            if let weekday = weekdayNumber(dayName) {
                let start = modifier == "this" ? now : cal.date(byAdding: .day, value: 1, to: now)!
                if let date = nextWeekday(weekday, from: start, calendar: cal) {
                    text.removeSubrange(range)
                    return cal.startOfDay(for: date)
                }
            }
        }

        let standalonePattern = #"^(monday|tuesday|wednesday|thursday|friday|saturday|sunday|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)[,\s]"#
        if let match = firstMatch(standalonePattern, in: lower), let range = Range(match.range, in: lower) {
            let dayName = groupString(match, group: 1, in: lower) ?? ""
            if let weekday = weekdayNumber(dayName),
               let date = nextWeekday(weekday, from: now, calendar: cal) {
                let wordRange = lower.range(of: dayName)!
                var end = wordRange.upperBound
                while end < lower.endIndex && (lower[end] == "," || lower[end] == " ") {
                    end = lower.index(after: end)
                }
                text.removeSubrange(wordRange.lowerBound..<end)
                return cal.startOfDay(for: date)
            }
        }
        return nil
    }

    private static func extractDetectorDate(from text: inout String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = detector.firstMatch(in: text, range: nsRange),
              let date = match.date,
              let matchRange = Range(match.range, in: text) else { return nil }

        let matchedText = String(text[matchRange])
        guard matchedText.count >= 5 else { return nil }

        let dayStart = Calendar.current.startOfDay(for: date)
        let today    = Calendar.current.startOfDay(for: Date())
        guard dayStart >= today else { return nil }

        text.removeSubrange(matchRange)
        return dayStart
    }

    // MARK: – Priority extraction

    private static let highKeywords   = ["super urgent","very urgent","extremely urgent","high priority",
                                         "urgent","asap","critical","immediately","emergency",
                                         "dringend","sofort","sehr wichtig"]
    private static let mediumKeywords = ["important","medium priority","moderate","soon",
                                         "wichtig","bald","mittlere priorität"]
    private static let lowKeywords    = ["low priority","whenever","someday","no rush","not urgent",
                                         "niedrige priorität","irgendwann"]

    private static func extractPriority(from text: inout String) -> Priority {
        let lower = text.lowercased()
        for kw in highKeywords   { if let r = lower.range(of: kw) { text.removeSubrange(r); return .high   } }
        for kw in mediumKeywords { if let r = lower.range(of: kw) { text.removeSubrange(r); return .medium } }
        for kw in lowKeywords    { if let r = lower.range(of: kw) { text.removeSubrange(r); return .low    } }
        return .none
    }

    // MARK: – Helpers

    private static func nextWeekday(_ weekday: Int, from date: Date, calendar: Calendar) -> Date? {
        var comps = DateComponents(); comps.weekday = weekday
        return calendar.nextDate(after: date, matching: comps, matchingPolicy: .nextTime)
    }

    private static func weekdayNumber(_ name: String) -> Int? {
        ["sunday":1,"monday":2,"tuesday":3,"wednesday":4,"thursday":5,"friday":6,"saturday":7,
         "sonntag":1,"montag":2,"dienstag":3,"mittwoch":4,"donnerstag":5,"freitag":6,"samstag":7][name.lowercased()]
    }

    private static func wordToInt(_ word: String) -> Int? {
        ["a":1,"one":1,"two":2,"three":3,"four":4,"five":5,"six":6,"seven":7,"eight":8,"nine":9,"ten":10,
         "ein":1,"einer":1,"zwei":2,"drei":3,"vier":4,"fuenf":5,"funf":5,"sechs":6,"sieben":7,"acht":8,"neun":9,"zehn":10][word.lowercased()]
    }

    private static func firstMatch(_ pattern: String, in text: String) -> NSTextCheckingResult? {
        (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))?
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func groupString(_ match: NSTextCheckingResult, group: Int, in text: String) -> String? {
        let r = match.range(at: group)
        guard r.location != NSNotFound, let range = Range(r, in: text) else { return nil }
        return String(text[range])
    }
}
