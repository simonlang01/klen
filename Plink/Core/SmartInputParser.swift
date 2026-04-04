import Foundation
import NaturalLanguage

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SmartInputResult {
    var title: String
    var desc: String
    var dueDate: Date?
    var priority: Priority
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
        @Guide(description: "A very short, action-oriented task title. Max 5 words. No filler. Examples: 'Call John', 'Send quarterly report', 'Buy groceries'.")
        var title: String

        @Guide(description: "Any additional context, details or notes not captured in the title. Empty string if none.")
        var description: String

        @Guide(description: "Priority level. Must be one of: none, low, medium, high.")
        var priority: String
    }

    @available(macOS 26, *)
    private static func parseWithFoundationModels(_ input: String) async -> SmartInputResult? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { return nil }

        let session = LanguageModelSession()

        let prompt = """
        Parse the following task input and extract a short title, optional description, and priority. \
        Keep all text in the same language as the input — do not translate.
        Input: \(input)
        """

        do {
            let response = try await session.respond(to: prompt, generating: LLMTaskResult.self)
            let result = response.content
            // Use deterministic NLTagger for date extraction — LLMs are unreliable for date arithmetic
            var textForDate = input
            let dueDate = extractDate(from: &textForDate)
            let priority: Priority = {
                switch result.priority.lowercased() {
                case "high":   return .high
                case "medium": return .medium
                case "low":    return .low
                default:       return .none
                }
            }()
            return SmartInputResult(title: result.title, desc: result.description, dueDate: dueDate, priority: priority)
        } catch {
            return nil
        }
    }
    #endif

    // MARK: – NLTagger path (always available)

    static func parseWithNLTagger(_ input: String) -> SmartInputResult {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let priority = extractPriority(from: &text)
        let dueDate  = extractDate(from: &text)
        text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let (title, desc) = splitTitleAndDesc(text)
        return SmartInputResult(title: title, desc: desc, dueDate: dueDate, priority: priority)
    }

    // MARK: – Title / Description split

    private static func splitTitleAndDesc(_ text: String) -> (String, String) {
        let separators = [" - ", " – ", " — ",
                          ", because ", " because ", " so that ", " since ",
                          ", weil ", " weil ", ", damit ", " damit ", ", da ", " denn ",
                          ". "]
        for sep in separators {
            if let range = text.range(of: sep, options: .caseInsensitive) {
                let candidate = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rest      = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty {
                    return (capitalize(shortenWithNL(candidate)), capitalize(rest))
                }
            }
        }
        let core = extractCoreAction(from: text)
        if !core.isEmpty && core.count < text.count {
            let rest = text.replacingOccurrences(of: core, with: "", options: .caseInsensitive)
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            return (capitalize(core), capitalize(rest))
        }
        return (capitalize(text), "")
    }

    private static func extractCoreAction(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var tokens: [(String, NLTag)] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                             scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if let tag { tokens.append((String(text[range]), tag)) }
            return true
        }
        guard let verbIdx = tokens.firstIndex(where: { $0.1 == .verb }) else {
            return tokens.prefix(4).map(\.0).joined(separator: " ")
        }
        var parts: [String] = []
        for token in tokens[verbIdx...] {
            if token.1 == .preposition || token.1 == .conjunction || token.1 == .adverb { break }
            parts.append(token.0)
            if parts.count >= 5 { break }
        }
        return parts.joined(separator: " ")
    }

    private static func shortenWithNL(_ text: String) -> String {
        let words = text.split(separator: " ")
        guard words.count > 5 else { return text }
        let core = extractCoreAction(from: text)
        return core.isEmpty ? text : core
    }

    // MARK: – Date extraction

    private static func extractDate(from text: inout String) -> Date? {
        if let result = extractRelativeDate(from: &text) { return result }
        return extractDetectorDate(from: &text)
    }

    private static func extractRelativeDate(from text: inout String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        let lower = text.lowercased()

        // ── Explicit named days (highest priority, most unambiguous) ──
        let namedDays: [(pattern: String, offset: Int)] = [
            (#"(?<!\w)(übermorgen|day after tomorrow)(?!\w)"#, 2),
            (#"(?<!\w)(morgen|tomorrow)(?!\w)"#,               1),
            (#"(?<!\w)(heute|today)(?!\w)"#,                   0),
        ]
        for (pattern, offset) in namedDays {
            if let match = firstMatch(pattern, in: lower), let range = Range(match.range, in: lower) {
                let date = cal.date(byAdding: .day, value: offset, to: now)!
                text.removeSubrange(range)
                // clean up stray comma/space left behind
                let trimmed = text.trimmingCharacters(in: .init(charactersIn: ", ").union(.whitespaces))
                text = trimmed
                return cal.startOfDay(for: date)
            }
        }

        // ── "nächste Woche" / "next week" / "nächsten Monat" / "next month" ──
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
            if unit.hasPrefix("day") || unit.hasPrefix("tag")   { comps.day   = n }
            if unit.hasPrefix("week") || unit.hasPrefix("woch") { comps.day   = n * 7 }
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

        // Reject matches that are too short — a single number like "3" or "03"
        // is almost certainly not an intended date (causes the "April 03" bug).
        // A real date string needs at least 5 characters (e.g. "15.04" or "Apr 5").
        let matchedText = String(text[matchRange])
        guard matchedText.count >= 5 else { return nil }

        // Reject dates in the past — if the detector guessed wrong the result
        // is always a past date (e.g. yesterday). Only future dates or today are valid.
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

    private static func capitalize(_ s: String) -> String {
        var result = s
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
