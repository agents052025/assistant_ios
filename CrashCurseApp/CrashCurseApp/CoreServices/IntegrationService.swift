import Foundation
import EventKit
import MessageUI
// Potentially SafariServices for bookmarks, though direct bookmark access is limited for privacy.

class IntegrationService: NSObject, MFMailComposeViewControllerDelegate {

    private let eventStore = EKEventStore()

    // MARK: - Calendar Integration
    func requestCalendarAccess(completion: @escaping (Bool, Error?) -> Void) {
        if #available(iOS 17.0, *) {
            // Use new iOS 17+ method
            eventStore.requestFullAccessToEvents { granted, error in
                completion(granted, error)
            }
        } else {
            // Use deprecated method for older iOS versions
            eventStore.requestAccess(to: .event) { (granted, error) in
                completion(granted, error)
            }
        }
    }

    func requestRemindersAccess(completion: @escaping (Bool, Error?) -> Void) {
        if #available(iOS 17.0, *) {
            // Use new iOS 17+ method
            eventStore.requestFullAccessToReminders { granted, error in
                completion(granted, error)
            }
        } else {
            // Use deprecated method for older iOS versions
            eventStore.requestAccess(to: .reminder) { (granted, error) in
                completion(granted, error)
            }
        }
    }

    func createCalendarEvent(title: String, startDate: Date, endDate: Date, notes: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        requestCalendarAccess { [weak self] granted, error in
            guard let self = self, granted, error == nil else {
                completion(false, error ?? NSError(domain: "IntegrationServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calendar access denied."]))
                return
            }

            let event = EKEvent(eventStore: self.eventStore)
            event.title = title
            event.startDate = startDate
            event.endDate = endDate
            event.notes = notes
            event.calendar = self.eventStore.defaultCalendarForNewEvents

            do {
                try self.eventStore.save(event, span: .thisEvent)
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    func createReminder(title: String, dueDate: Date? = nil, notes: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        requestRemindersAccess { [weak self] granted, error in
            guard let self = self, granted, error == nil else {
                completion(false, error ?? NSError(domain: "IntegrationServiceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Reminders access denied."]))
                return
            }

            let reminder = EKReminder(eventStore: self.eventStore)
            reminder.title = title
            reminder.notes = notes
            reminder.calendar = self.eventStore.defaultCalendarForNewReminders()
            
            if let dueDate = dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            }

            do {
                try self.eventStore.save(reminder, commit: true)
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
    }

    // Convenience method for ChatViewController
    func createReminder(title: String, date: Date, notes: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        createReminder(title: title, dueDate: date, notes: notes, completion: completion)
    }

    // MARK: - Mail Integration
    func canSendMail() -> Bool {
        return MFMailComposeViewController.canSendMail()
    }

    func presentMailComposer(from viewController: UIViewController, subject: String, body: String, recipients: [String]? = nil) {
        if canSendMail() {
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            mailComposer.setSubject(subject)
            mailComposer.setMessageBody(body, isHTML: false)
            if let recipients = recipients {
                mailComposer.setToRecipients(recipients)
            }
            viewController.present(mailComposer, animated: true)
        } else {
            // Handle the case where the device cannot send mail (e.g., show an alert)
            print("Mail services are not available")
        }
    }

    // MFMailComposeViewControllerDelegate method
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
        // Handle mail compose result (e.g., sent, saved, cancelled, failed)
        switch result {
        case .cancelled: print("Mail cancelled")
        case .saved: print("Mail saved")
        case .sent: print("Mail sent")
        case .failed: print("Mail failed: \(error?.localizedDescription ?? "Unknown error")")
        @unknown default: print("Mail: Unknown result")
        }
    }
    
    // MARK: - Safari/Bookmarks (Conceptual - Direct access is restricted)
    // Direct access to Safari bookmarks is not provided by iOS for privacy reasons.
    // You could potentially integrate with a read-it-later service or use SFSafariViewController to open URLs.
    func openURLInSafari(_ url: URL, from viewController: UIViewController) {
        // Consider using SFSafariViewController for a better in-app browser experience
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
} 