import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling.
// Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(DefaultsMacrosDeclarations)
@testable import DefaultsMacros
@testable import DefaultsMacrosDeclarations

let testMacros: [String: Macro.Type] = [
	"ObservableDefault": ObservableDefaultMacro.self
]
#else
let testMacros: [String: Macro.Type] = [:]
#endif

final class ObservableDefaultMacroTests: XCTestCase {
	func testExpansionWithMemberSyntax() throws {
		#if canImport(DefaultsMacrosDeclarations)
		assertMacroExpansion(
			declaration(for: "Defaults.Keys.name"),
			expandedSource: expectedExpansion(for: "Defaults.Keys.name"),
			macros: testMacros,
			indentationWidth: .tabs(1)
		)
		#else
		throw XCTSkip("Macros are only supported when running tests for the host platform")
		#endif
	}

	func testExpansionWithDotSyntax() throws {
		#if canImport(DefaultsMacrosDeclarations)
		assertMacroExpansion(
			declaration(for: ".name"),
			expandedSource: expectedExpansion(for: ".name"),
			macros: testMacros,
			indentationWidth: .tabs(1)
		)
		#else
		throw XCTSkip("Macros are only supported when running tests for the host platform")
		#endif
	}

	func testExpansionWithFunctionCall() throws {
		#if canImport(DefaultsMacrosDeclarations)
		assertMacroExpansion(
			declaration(for: "getName()"),
			expandedSource: expectedExpansion(for: "getName()"),
			macros: testMacros,
			indentationWidth: .tabs(1)
		)
		#else
		throw XCTSkip("Macros are only supported when running tests for the host platform")
		#endif
	}

	func testExpansionWithProperty() throws {
		#if canImport(DefaultsMacrosDeclarations)
		assertMacroExpansion(
			declaration(for: "propertyName"),
			expandedSource: expectedExpansion(for: "propertyName"),
			macros: testMacros,
			indentationWidth: .tabs(1)
		)
		#else
		throw XCTSkip("Macros are only supported when running tests for the host platform")
		#endif
	}

	private func declaration(for keyExpression: String) -> String {
		#"""
		@Observable
		class ObservableClass {
			@ObservableDefault(\#(keyExpression))
			@ObservationIgnored
			var name: String
		}
		"""#
	}

	private func expectedExpansion(for keyExpression: String) -> String {
		#"""
		@Observable
		class ObservableClass {
			@ObservationIgnored
			var name: String {
				get {
					let taskStorage = Self._observationTask_name
					taskStorage.installIfNeeded(for: self, create: {
						let updates = Defaults.updates(\#(keyExpression), initial: false)
						let (startStream, startContinuation) = AsyncStream<Void>.makeStream()
						class WeakOwnerBox<Value: AnyObject>: @unchecked Sendable {
							// The task below inherits this accessor's actor. This box only
							// carries a weak reference, whose zeroing is managed by ARC.
							weak var value: Value?

							init(inner: Value) {
								self.value = inner
							}
						}
						let selfBox = WeakOwnerBox(inner: self)
						let task = Task<Void, Never> { [selfBox, updates] in
							var startIterator = startStream.makeAsyncIterator()
							guard await startIterator.next() != nil else {
								return
							}
							for await _ in updates {
								guard let self = selfBox.value else {
									return
								}
								self.withMutation(keyPath: \.name) { }
							}
						}
						return (task: task, start: startContinuation)
					}, start: { startContinuation in
						startContinuation.yield()
						startContinuation.finish()
					})
					access(keyPath: \.name)
					return Defaults[\#(keyExpression)]
				}
				set {
					withMutation(keyPath: \.name) {
						Defaults[\#(keyExpression)] = newValue
					}
				}
			}

			private static let _observationTask_name = Defaults.ObservableDefaultTaskStorage()
		}
		"""#
	}
}
