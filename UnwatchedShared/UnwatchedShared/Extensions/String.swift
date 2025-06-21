//
//  String.swift
//  UnwatchedShared
//

public extension String {
    var bool: Bool? {
        UserDefaults.standard.value(forKey: self) as? Bool
    }
}
