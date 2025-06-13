//
//  StoreKitHelper.swift
//  plugin_iap
//
//  Created by Usman Mughal on 13/06/2025.
//

import Foundation
import StoreKit

@MainActor
@objcMembers
@available(iOS 15.0, *)
public class StoreKitHelper: NSObject {

    public static let shared = StoreKitHelper()

    private override init() {}

    /// Checks if the product identified by `productId` is eligible for an intro offer.
    public func isEligibleForIntroOffer(for productId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let products = try await Product.products(for: [productId])
                guard let product = products.first,
                      let subscription = product.subscription else {
                    completion(false)
                    return
                }
                let isEligible = await subscription.isEligibleForIntroOffer
                completion(isEligible)
            } catch {
                print("Error fetching products or eligibility: \(error)")
                completion(false)
            }
        }
    }
}



