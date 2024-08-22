//
//  ViewModelDelegate.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-03-02.
//

import Foundation
import os

protocol ViewModelDelegate {
    var logger: Logger? { get set }
    func showAlert(withText: String)
    var trimSpeed: Double { get }
}
