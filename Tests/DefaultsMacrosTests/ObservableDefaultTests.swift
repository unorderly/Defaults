import Defaults
import DefaultsMacros
import Foundation
import Observation
import Testing

private let animalKey = "animalKey"
private let defaultAnimal = "cat"
private let newAnimal = "unicorn"

private let colorKey = "colorKey"
private let defaultColor = "blue"
private let newColor = "purple"

private let testSetKey = "testSetKey"
private let mainActorKey = "mainActorKey"
private let defaultMainActorValue = "before"
private let newMainActorValue = "after"

extension Defaults.Keys {
	static let animal = Defaults.Key(animalKey, default: defaultAnimal)
	static let color = Defaults.Key(colorKey, default: defaultColor)
	static let testSet = Defaults.Key(testSetKey, default: Set<Int>())
	static let mainActorValue = Defaults.Key(mainActorKey, default: defaultMainActorValue)
}

func getKey() -> Defaults.Key<String> {
	.animal
}

let keyProperty = Defaults.Keys.animal

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class TestModelWithDotSyntax: Sendable {
	@ObservableDefault(.animal)
	@ObservationIgnored
	var animal: String
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class TestModelWithFunctionCall {
	@ObservableDefault(getKey())
	@ObservationIgnored
	var animal: String
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
final class TestModelWithProperty {
	@ObservableDefault(keyProperty)
	@ObservationIgnored
	var animal: String
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class TestModelWithMemberSyntax {
	@ObservableDefault(Defaults.Keys.animal)
	@ObservationIgnored
	var animal: String
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class TestModelWithMultipleValues {
	@ObservableDefault(.animal)
	@ObservationIgnored
	var animal: String

	@ObservableDefault(.color)
	@ObservationIgnored
	var color: String
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
@Observable
private final class TestModelWithSet {
	@ObservableDefault(.testSet)
	@ObservationIgnored
	var testSet: Set<Int>
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
@MainActor @Observable
private final class MainActorTestModel {
	@ObservableDefault(.mainActorValue)
	@ObservationIgnored
	var value: String
}

private final class ConcurrentStorageOwner: @unchecked Sendable {}

private final class LockedCounter: @unchecked Sendable {
	private let lock = NSLock()
	private var count = 0

	func increment() {
		lock.lock()
		count += 1
		lock.unlock()
	}

	func value() -> Int {
		lock.lock()
		defer { lock.unlock() }
		return count
	}
}

@Suite(.serialized, .timeLimit(.minutes(1)))
final class ObservableDefaultTests {
	init() {
		Defaults.removeAll()
		Defaults[.animal] = defaultAnimal
		Defaults[.color] = defaultColor
		Defaults[.testSet] = []
		Defaults[.mainActorValue] = defaultMainActorValue
	}

	deinit {
		Defaults.removeAll()
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test
	func testMacroWithMemberSyntax() async {
		let model = TestModelWithMemberSyntax()
		#expect(model.animal == defaultAnimal)

		let userDefaultsValue = UserDefaults.standard.string(forKey: animalKey)
		#expect(userDefaultsValue == defaultAnimal)

		let (changeStream, changeContinuation) = AsyncStream<Void>.makeStream()
		await confirmation { confirmation in
			_ = withObservationTracking {
				model.animal
			} onChange: {
				confirmation()
				changeContinuation.yield()
				changeContinuation.finish()
			}

			UserDefaults.standard.set(newAnimal, forKey: animalKey)
			var changeIterator = changeStream.makeAsyncIterator()
			_ = await changeIterator.next()
		}

		#expect(model.animal == newAnimal)
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test
	func testMacroWithDotSyntax() async {
		let model = TestModelWithDotSyntax()
		#expect(model.animal == defaultAnimal)

		let userDefaultsValue = UserDefaults.standard.string(forKey: animalKey)
		#expect(userDefaultsValue == defaultAnimal)

		let (changeStream, changeContinuation) = AsyncStream<Void>.makeStream()
		await confirmation { confirmation in
			_ = withObservationTracking {
				model.animal
			} onChange: {
				confirmation()
				changeContinuation.yield()
				changeContinuation.finish()
			}

			UserDefaults.standard.set(newAnimal, forKey: animalKey)
			var changeIterator = changeStream.makeAsyncIterator()
			_ = await changeIterator.next()
		}

		#expect(model.animal == newAnimal)
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test
	func testMacroWithFunctionCall() async {
		let model = TestModelWithFunctionCall()
		#expect(model.animal == defaultAnimal)

		let userDefaultsValue = UserDefaults.standard.string(forKey: animalKey)
		#expect(userDefaultsValue == defaultAnimal)

		let (changeStream, changeContinuation) = AsyncStream<Void>.makeStream()
		await confirmation { confirmation in
			_ = withObservationTracking {
				model.animal
			} onChange: {
				confirmation()
				changeContinuation.yield()
				changeContinuation.finish()
			}

			UserDefaults.standard.set(newAnimal, forKey: animalKey)
			var changeIterator = changeStream.makeAsyncIterator()
			_ = await changeIterator.next()
		}

		#expect(model.animal == newAnimal)
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test
	func testMacroWithProperty() async {
		let model = TestModelWithProperty()
		#expect(model.animal == defaultAnimal)

		let userDefaultsValue = UserDefaults.standard.string(forKey: animalKey)
		#expect(userDefaultsValue == defaultAnimal)

		let (changeStream, changeContinuation) = AsyncStream<Void>.makeStream()
		await confirmation { confirmation in
			_ = withObservationTracking {
				model.animal
			} onChange: {
				confirmation()
				changeContinuation.yield()
				changeContinuation.finish()
			}

			UserDefaults.standard.set(newAnimal, forKey: animalKey)
			var changeIterator = changeStream.makeAsyncIterator()
			_ = await changeIterator.next()
		}

		#expect(model.animal == newAnimal)
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test
	func testMacroWithMultipleValues() async {
		let model = TestModelWithMultipleValues()
		#expect(model.animal == defaultAnimal)
		#expect(model.color == defaultColor)

		let (animalChangeStream, animalChangeContinuation) = AsyncStream<Void>.makeStream()
		let (colorChangeStream, colorChangeContinuation) = AsyncStream<Void>.makeStream()
		await confirmation(expectedCount: 2) { confirmation in
			_ = withObservationTracking {
				model.animal
			} onChange: {
				confirmation()
				animalChangeContinuation.yield()
				animalChangeContinuation.finish()
			}

			_ = withObservationTracking {
				model.color
			} onChange: {
				confirmation()
				colorChangeContinuation.yield()
				colorChangeContinuation.finish()
			}

			UserDefaults.standard.set(newAnimal, forKey: animalKey)
			UserDefaults.standard.set(newColor, forKey: colorKey)
			var animalChangeIterator = animalChangeStream.makeAsyncIterator()
			_ = await animalChangeIterator.next()
			var colorChangeIterator = colorChangeStream.makeAsyncIterator()
			_ = await colorChangeIterator.next()
		}

		#expect(model.animal == newAnimal)
		#expect(model.color == newColor)
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test
	func testMacroWithSetNoInfiniteRecursion() async {
		let model = TestModelWithSet()
		#expect(model.testSet.isEmpty)

		// This should not cause infinite recursion
		model.testSet.formUnion(1...10)

		#expect(model.testSet == Set(1...10))
		#expect(Defaults[.testSet] == Set(1...10))
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test
	func testMacroObserversPropagateAcrossModels() async {
		let model1 = TestModelWithSet()
		let model2 = TestModelWithSet()

		#expect(model1.testSet.isEmpty)
		#expect(model2.testSet.isEmpty)

		let (changeStream, changeContinuation) = AsyncStream<Void>.makeStream()
		await confirmation { confirmation in
			_ = withObservationTracking {
				model2.testSet
			} onChange: {
				confirmation()
				changeContinuation.yield()
				changeContinuation.finish()
			}

			// Write through model1
			model1.testSet = [1, 2, 3]
			var changeIterator = changeStream.makeAsyncIterator()
			_ = await changeIterator.next()
		}

		// model2 should have observed the change
		#expect(model2.testSet == [1, 2, 3])
	}

	@available(macOS 14, iOS 17, tvOS 17, watchOS 10, visionOS 1, *)
	@Test @MainActor
	func testMainActorModelObservesExternalWrite() async {
		let model = MainActorTestModel()
		#expect(model.value == defaultMainActorValue)

		let (changeStream, changeContinuation) = AsyncStream<Void>.makeStream()
		await confirmation { valueDidChange in
			_ = withObservationTracking {
				model.value
			} onChange: {
				valueDidChange()
				changeContinuation.yield()
				changeContinuation.finish()
			}

			Task.detached {
				Defaults[.mainActorValue] = newMainActorValue
			}
			var changeIterator = changeStream.makeAsyncIterator()
			_ = await changeIterator.next()
		}

		#expect(model.value == newMainActorValue)
	}

	@Test
	func testConcurrentFirstAccessInstallsOneTask() async {
		let storage = Defaults.ObservableDefaultTaskStorage()
		let owner = ConcurrentStorageOwner()
		let installCount = LockedCounter()

		await withTaskGroup(of: Void.self) { group in
			for _ in 0..<16 {
				group.addTask {
					storage.installIfNeeded(for: owner, create: {
						installCount.increment()
						let (stream, continuation) = AsyncStream<Void>.makeStream()
						let task = Task<Void, Never> {
							for await _ in stream {}
						}
						return (task: task, start: continuation)
					}, start: { continuation in
						continuation.finish()
					})
				}
			}
		}

		#expect(installCount.value() == 1)
	}

	@Test
	func testTaskStorageCancelsWhenOwnerDeinitializes() async {
		let storage = Defaults.ObservableDefaultTaskStorage()
		var owner: NSObject? = NSObject()
		let (startedStream, startedContinuation) = AsyncStream<Void>.makeStream()
		let (terminationStream, terminationContinuation) = AsyncStream<Void>.makeStream()

		storage.installIfNeeded(for: owner!, create: {
			let (updates, updatesContinuation) = AsyncStream<Void>.makeStream()
			updatesContinuation.onTermination = { _ in
				terminationContinuation.yield()
				terminationContinuation.finish()
			}
			let (startStream, startContinuation) = AsyncStream<Void>.makeStream()
			let task = Task<Void, Never> { [updates, updatesContinuation, startStream] in
				defer { updatesContinuation.finish() }
				var startIterator = startStream.makeAsyncIterator()
				guard await startIterator.next() != nil else {
					return
				}
				startedContinuation.yield()
				startedContinuation.finish()
				for await _ in updates {}
			}
			return (task: task, start: startContinuation)
		}, start: { startContinuation in
			startContinuation.yield()
			startContinuation.finish()
		})

		var startedIterator = startedStream.makeAsyncIterator()
		_ = await startedIterator.next()
		owner = nil

		var terminationIterator = terminationStream.makeAsyncIterator()
		_ = await terminationIterator.next()
	}
}
