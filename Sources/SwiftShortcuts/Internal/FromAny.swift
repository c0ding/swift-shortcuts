import CSymbols

// MARK: - AnyShortcut from Any

extension AnyShortcut {
    init?(_fromValue value: Any) {
        // Synthesize a fake protocol conformance record to AnyShortcutConvertible
        let conformance = ProtocolConformanceRecord(type: type(of: value), witnessTable: 0)
        let type = unsafeBitCast(conformance, to: AnyShortcutConvertible.Type.self)

        guard let action = type.anyShortcut(from: value) else {
            return nil
        }

        self = action
    }
}

// MARK: - AnyViewConvertible

private let actionMetadata: ProtocolMetadata = {
    let module = "SwiftShortcuts"
    let name = "Shortcut"
    let postfix = "_p"
    let mangled = "\(module.count)\(module)\(name.count)\(name)\(postfix)"
    return ProtocolMetadata(type: _typeByName(mangled)!)
}()

private protocol AnyShortcutConvertible {}

extension AnyShortcutConvertible {
    static func anyShortcut(from action: Any) -> AnyShortcut? {
        guard let witnessTable = _conformsToProtocol(Self.self, actionMetadata.protocolDescriptorVector) else {
            return nil
        }

        let conformanceRecord = ProtocolConformanceRecord(type: Self.self, witnessTable: Int(bitPattern: witnessTable))
        return withUnsafePointer(to: action as! Self) { pointer in makeAnyShortcut(pointer, conformanceRecord) }
    }
}

@_silgen_name("_swift_shortcuts_makeAnyShortcut")
public func _makeAnyShortcut<S: Shortcut>(from shortcut: S) -> AnyShortcut {
    return AnyShortcut(shortcut)
}

private typealias AnyShortcutFunction = @convention(thin) (UnsafeRawPointer, ProtocolConformanceRecord) -> AnyShortcut

private let makeAnyShortcut: AnyShortcutFunction = {
    let pointer = SwiftShortcutsGetAddressForSymbol(SwiftShortcutsSymbolMakeAnyShortcut)
    return unsafeBitCast(pointer, to: AnyShortcutFunction.self)
}()

// MARK: - [ActionComponent] from Any

private protocol ActionsConvertible {}

extension ActionsConvertible {
    static func actions(from shortcut: Any) -> [Action]? {
        guard let witnessTable = _conformsToProtocol(Self.self, actionMetadata.protocolDescriptorVector) else {
            return nil
        }

        let conformanceRecord = ProtocolConformanceRecord(type: Self.self, witnessTable: Int(bitPattern: witnessTable))
        return withUnsafePointer(to: shortcut as! Self) { pointer in decompose(pointer, conformanceRecord) }
    }
}

@_silgen_name("_swift_shortcuts_decompose")
public func _decompose<S: Shortcut>(shortcut: S) -> [Action] {
    if S.Body.self == Never.self {
        return shortcut.decompose()
    }

    let body = shortcut.body
    if let component = body as? Action {
        return [component]
    } else {
        return _decompose(shortcut: body)
    }
}

private typealias DecomposeFunction = @convention(thin) (UnsafeRawPointer, ProtocolConformanceRecord) -> [Action]

private let decompose: DecomposeFunction = {
    let pointer = SwiftShortcutsGetAddressForSymbol(SwiftShortcutsSymbolDecompose)
    return unsafeBitCast(pointer, to: DecomposeFunction.self)
}()

func actionComponents(from value: Any) -> [Action]? {
    // Synthesize a fake protocol conformance record to ActionStepsConvertible
    let conformance = ProtocolConformanceRecord(type: type(of: value), witnessTable: 0)
    let type = unsafeBitCast(conformance, to: ActionsConvertible.Type.self)
    return type.actions(from: value)
}

// MARK: - Protocol Runtime Information

private struct ProtocolConformanceRecord {
    let type: Any.Type
    let witnessTable: Int
}

private struct ProtocolDescriptor {}

private struct ProtocolMetadata {
    let kind: Int
    let layoutFlags: UInt32
    let numberOfProtocols: UInt32
    let protocolDescriptorVector: UnsafeMutablePointer<ProtocolDescriptor>

    init(type: Any.Type) {
        self = unsafeBitCast(type, to: UnsafeMutablePointer<Self>.self).pointee
    }
}

@_silgen_name("swift_conformsToProtocol")
private func _conformsToProtocol(
    _ type: Any.Type,
    _ protocolDescriptor: UnsafeMutablePointer<ProtocolDescriptor>
) -> UnsafeRawPointer?
