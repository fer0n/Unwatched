import Foundation

extension Double {
    // enable an optional value and parse it as a doouble here, otherwise nil
    init?(_ optionalString: String?) {
        guard let string = optionalString else { return nil }
        self.init(string)
    }
}
