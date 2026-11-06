//
//  GameCenterInviteView.swift
//  FinalProject
//
//  Created by Vincenzo Picone on 19/05/25.
//

import SwiftUI
import GameKit

struct GameCenterInviteView: UIViewControllerRepresentable {
    let minPlayers: Int
    let maxPlayers: Int
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        
        DispatchQueue.main.async {
            let request = GKMatchRequest()
            request.minPlayers = self.minPlayers
            request.maxPlayers = self.maxPlayers
            
            guard let mmvc = GKMatchmakerViewController(matchRequest: request) else { return }
            mmvc.matchmakerDelegate = context.coordinator
            controller.present(mmvc, animated: true)
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    class Coordinator: NSObject, GKMatchmakerViewControllerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
            viewController.dismiss(animated: true) {
                self.isPresented = false
            }
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
            viewController.dismiss(animated: true) {
                self.isPresented = false
            }
            DispatchQueue.main.async {
                GameKitManager.shared.errorMessage = "Errore invito: \(error.localizedDescription)"
            }
        }

        func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
            viewController.dismiss(animated: true) {
                self.isPresented = false
            }
            // Delega al GameKitManager
            GameKitManager.shared.matchmakerViewController(viewController, didFind: match)
        }
    }
}
