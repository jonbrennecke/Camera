import Foundation

class Observer {
  private let uuid = UUID()

  internal var isPaused = false
}

extension Observer: Equatable {
  static func == (lhs: Observer, rhs: Observer) -> Bool {
    return lhs.uuid == rhs.uuid
  }
}

private final class WeakReference<T> where T: AnyObject {
  internal weak var value: T?

  init(value: T?) {
    self.value = value
  }
}

class ObserverCollection<T: Observer> {
  private var observers = [WeakReference<T>]()

  public var count: Int {
    return observers.count
  }

  public func removeObserver(_ observer: T) {
    observers.removeAll { ref in
      guard let value = ref.value else { return false }
      return value == observer
    }
  }

  public func addObserver(_ observer: T) {
    observers.append(WeakReference(value: observer))
  }

  public func forEach(_ body: (T) throws -> Void) rethrows {
    try observers.forEach { ref in
      guard let value = ref.value else {
        return
      }
      try body(value)
    }
  }
}
