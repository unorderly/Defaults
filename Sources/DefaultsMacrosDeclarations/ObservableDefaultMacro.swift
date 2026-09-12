import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/**
 Macro declaration for the ``ObservableDefault`` macro.
*/
public struct ObservableDefaultMacro {}

/**
Conforming to ``AccessorMacro`` allows us to add the property accessors (get/set) that integrate with ``Observable``.
*/
extension ObservableDefaultMacro: AccessorMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingAccessorsOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws(ObservableDefaultMacroError) -> [AccessorDeclSyntax] {
		let property = try propertyPattern(of: declaration)
		let expression = try keyExpression(of: node)
		let associatedKey = associatedKeyToken(for: property)

		// The get/set accessors follow the same pattern that @Observable uses to handle the mutations.
		//
		// The get accessor also sets up an observation to update the value when the UserDefaults
		// changes from elsewhere.
		return [
			#"""
			get {
				let taskStorage = Self.\#(associatedKey)
				taskStorage.installIfNeeded(for: self, create: {
					let updates = Defaults.updates(\#(expression), initial: false)
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
							self.withMutation(keyPath: \.\#(property)) { }
						}
					}
					return (task: task, start: startContinuation)
				}, start: { startContinuation in
					startContinuation.yield()
					startContinuation.finish()
				})
				access(keyPath: \.\#(property))
				return Defaults[\#(expression)]
			}
			"""#,
			#"""
			set {
				withMutation(keyPath: \.\#(property)) {
					Defaults[\#(expression)] = newValue
				}
			}
			"""#
		]
	}
}

/**
Conforming to ``PeerMacro`` adds static storage for the task that updates the original property whenever the UserDefaults value changes outside the class.
*/
extension ObservableDefaultMacro: PeerMacro {
	public static func expansion(
		of node: SwiftSyntax.AttributeSyntax,
		providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
		in context: some SwiftSyntaxMacros.MacroExpansionContext
	) throws -> [SwiftSyntax.DeclSyntax] {
		let property = try propertyPattern(of: declaration)
		let associatedKey = associatedKeyToken(for: property)

		return [
			"private static let \(associatedKey) = Defaults.ObservableDefaultTaskStorage()"
		]
	}
}

// Logic used by both macro implementations
extension ObservableDefaultMacro {
	/**
	Extracts the pattern (i.e. the name) of the attached property.
	*/
	private static func propertyPattern(
		of declaration: some SwiftSyntax.DeclSyntaxProtocol
	) throws(ObservableDefaultMacroError) -> TokenSyntax {
		// Must be attached to a property declaration.
		guard let variableDeclaration = declaration.as(VariableDeclSyntax.self) else {
			throw .notAttachedToProperty
		}

		// Must be attached to a variable property (i.e. `var` and not `let`).
		guard variableDeclaration.bindingSpecifier.tokenKind == .keyword(.var) else {
			throw .notAttachedToVariable
		}

		// Must be attached to a single property.
		guard variableDeclaration.bindings.count == 1, let binding = variableDeclaration.bindings.first else {
			throw .notAttachedToSingleProperty
		}

		// Must not provide an initializer for the property (i.e. not assign a value).
		guard binding.initializer == nil else {
			throw .attachedToPropertyWithInitializer
		}

		// Must not be attached to property with existing accessor block.
		guard binding.accessorBlock == nil else {
			throw .attachedToPropertyWithAccessorBlock
		}

		// Must use Identifier Pattern.
		// See https://swiftinit.org/docs/swift-syntax/swiftsyntax/identifierpatternsyntax
		guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
			throw .attachedToPropertyWithoutIdentifierProperty
		}

		return pattern
	}

	/**
	Extracts the expression used to define the Defaults.Key in the macro call.
	*/
	private static func keyExpression(
		of node: AttributeSyntax
	) throws(ObservableDefaultMacroError) -> ExprSyntax {
		// Must receive arguments
		guard let arguments = node.arguments else {
			throw .calledWithoutArguments
		}

		// Must be called with Labeled Expression.
		// See https://swiftinit.org/docs/swift-syntax/swiftsyntax/labeledexprlistsyntax
		guard let expressionList = arguments.as(LabeledExprListSyntax.self) else {
			throw .calledWithoutLabeledExpression
		}

		// Must only receive one argument.
		guard expressionList.count == 1, let expression = expressionList.first?.expression else {
			throw .calledWithMultipleArguments
		}

		return expression
	}

	/**
	 Generates the static task-storage property name for the UserDefaults observation.
	 */
	private static func associatedKeyToken(for property: TokenSyntax) -> TokenSyntax {
		"_observationTask_\(property)"
	}
}

/**
Error handling for ``ObservableDefaultMacro``.
*/
public enum ObservableDefaultMacroError: Error {
	case notAttachedToProperty
	case notAttachedToVariable
	case notAttachedToSingleProperty
	case attachedToPropertyWithInitializer
	case attachedToPropertyWithAccessorBlock
	case attachedToPropertyWithoutIdentifierProperty
	case calledWithoutArguments
	case calledWithoutLabeledExpression
	case calledWithMultipleArguments
	case calledWithoutFunctionSyntax
	case calledWithoutKeyArgument
	case calledWithUnsupportedExpression
}

extension ObservableDefaultMacroError: CustomStringConvertible {
	public var description: String {
		switch self {
		case .notAttachedToProperty:
			"@ObservableDefault must be attached to a property."
		case .notAttachedToVariable:
			"@ObservableDefault must be attached to a `var` property."
		case .notAttachedToSingleProperty:
			"@ObservableDefault can only be attached to a single property."
		case .attachedToPropertyWithInitializer:
			"@ObservableDefault must not be attached with a property with a value assigned. To create set default value, provide it in the `Defaults.Key` definition."
		case .attachedToPropertyWithAccessorBlock:
			"@ObservableDefault must not be attached to a property with accessor block."
		case .attachedToPropertyWithoutIdentifierProperty:
			"@ObservableDefault could not identify the attached property."
		case .calledWithoutArguments,
			 .calledWithoutLabeledExpression,
			 .calledWithMultipleArguments,
			 .calledWithoutFunctionSyntax,
			 .calledWithoutKeyArgument,
			 .calledWithUnsupportedExpression:
			"@ObservableDefault must be called with (1) argument of type `Defaults.Key`"
		}
	}
}
