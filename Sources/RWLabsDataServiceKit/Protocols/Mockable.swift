//
//  Mockable.swift
//  ThirtyPlusPanel
//
//  Created by Raunak Joneja on 06/04/26.
//

public protocol Mockable {
    associatedtype Mock
    static var mock: Mock { get }
}
