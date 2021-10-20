//import Foundation
//
//enum Locale {
//  // TODO: Adds l10n support.
//  static var undefined: String { "undefined" }
//  static var undefinedHelp: String { "The stream has not been named yet." }
//  static var renameTitle: String { "Rename Stream" }
//  static var renamePrompt: String { "Add a custom identifier for the selected stream." }
//  static var renameFailed: String { "The stream name is already in use."}
//  static var renameNodeTitle: String { "Set calculator name" }
//  static var renameNodePrompt: String { "Set the calculator name for this node." }
//  static var addStreamTitle: String { "Add new stream" }
//  static var addStreamPrompt: String { "Add a new input/output stream for this node." }
//  static var delete: String { "Delete" }
//  static var rename: String { "Rename" }
//  static var renameHelp: String { "Click to rename the stream." }
//  static var inputs: String { "Input Streams" }
//  static var outputs: String { "Output Streams" }
//  static var noStreams: String { "No streams defined." }
//  static var removeSocketHelp: String { "Remove the stream from this node." }
//  static var settingsHelp: String { "Configure this node" }
//  static var deleteHelp: String { "Remove this node" }
//}
//
//import SwiftUI
//
//class PatchStore: ObservableObject {
//  @Published var nodes: [PatchNode] = []
//  @Published var selectedNodeID: Int?
//  @Published var selectedConnection: PatchConnection? = nil
//  var connections: [PatchSocketID: [PatchConnection]] { nodes.connections }
//  var delegate: PatchEditorDelegate?
//
//  // MARK: - Mutations
//
//  func add(originID: PatchSocketID, destinationID: PatchSocketID) {
//    assert(Thread.isMainThread)
//    guard let (origin, _) = findSocketPair(
//      originID: originID,
//      destinationID: destinationID)
//    else {
//      // Could not find the sockets with the given IDs.
//      return
//    }
//    guard
//      !connections.values.flatMap({ $0 }).map({ $0.destinationID }).contains(destinationID)
//    else {
//      // The socket has already an attached stream.
//      return
//    }
//    let connection = PatchConnection(originID: originID, destinationID: destinationID)
//    guard delegate?.shouldAddConnection(connection) ?? true else {
//      // The connection is not available.
//      return
//    }
//    if origin.connections.contains(where: { $0.destinationID == destinationID }) { return }
//    origin.addConnection(destinationID: destinationID)
//    delegate?.didChangePatchNodes(nodes)
//    objectWillChange.send()
//  }
//
//  func remove(originID: PatchSocketID, destinationID: PatchSocketID) {
//    assert(Thread.isMainThread)
//    guard let (origin, _) = findSocketPair(
//      originID: originID,
//      destinationID: destinationID)
//    else {
//      // Could not find the sockets with the given IDs.
//      return
//    }
//    origin.connections = origin.connections.filter { $0.destinationID != destinationID }
//    delegate?.didChangePatchNodes(nodes)
//    objectWillChange.send()
//  }
//
//  @discardableResult
//  func rename(originID: PatchSocketID, name: String) -> Bool {
//    assert(Thread.isMainThread)
//    let allOutputSockets = nodes.flatMap { $0.outputs }
//    guard let socket = allOutputSockets.filter({ $0.id == originID }).first else {
//      // Could not find the output socket with the given ID.
//      return false
//    }
//    let names = Set<String>(allOutputSockets.compactMap { $0.name })
//    guard !names.contains(name) else {
//      // Names must me unique.
//      return false
//    }
//    socket.name = name
//    delegate?.didChangePatchNodes(nodes)
//    objectWillChange.send()
//    return true
//  }
//
//  func streamName(originID: PatchSocketID) -> String? {
//    assert(Thread.isMainThread)
//    guard let socket = nodes.flatMap({ $0.outputs }).filter({ $0.id == originID }).first else {
//      return nil
//    }
//    return socket.name
//  }
//
//  func remove(node: PatchNode) {
//    assert(Thread.isMainThread)
//    for socket in node.outputs where !socket.connections.isEmpty {
//      let originID = socket.id
//      for destinationID in socket.connections {
//        remove(originID: originID, destinationID: destinationID.destinationID)
//      }
//    }
//    for (originID, destinations) in connections {
//      for destination in destinations.filter({ $0.destinationID.nodeID == node.id }) {
//        remove(originID: originID, destinationID: destination.destinationID)
//      }
//    }
//    nodes = nodes.filter { $0.id != node.id }
//    delegate?.didChangePatchNodes(nodes)
//    objectWillChange.send()
//  }
//
//  func remove(socket: PatchSocket) {
//    assert(Thread.isMainThread)
//    guard let socketNode = nodes.first(where: { $0.id == socket.id.nodeID }) else {
//      // Could not find the node with the given index.
//      return
//    }
//    for node in nodes {
//      for output in node.outputs {
//        output.connections = output.connections.filter { $0.destinationID != socket.id }
//      }
//    }
//    socketNode.inputs = socketNode.inputs.filter { $0.id != socket.id }
//    socketNode.outputs = socketNode.outputs.filter { $0.id != socket.id }
//    self.delegate?.didChangePatchNodes(self.nodes)
//    self.objectWillChange.send()
//  }
//
//
//  // MARK: - Private
//
//  private func findSocketPair(
//    originID: PatchSocketID,
//    destinationID: PatchSocketID
//  ) -> (PatchSocket, PatchSocket)? {
//    assert(Thread.isMainThread)
//    let allInputSocket = nodes.flatMap { $0.inputs }
//    let allOutputSockets = nodes.flatMap { $0.outputs }
//    guard
//      let origin = allOutputSockets.first(where: { $0.id == originID }),
//      let destination = allInputSocket.first(where: { $0.id == destinationID })
//    else {
//      return nil
//    }
//    return (origin, destination)
//  }
//
//  // MARK: - Prompts
//
//  func showRenamePrompt(originID: PatchSocketID) {
//    NSAppModalTextField(title: Locale.renameTitle, prompt: Locale.renamePrompt) {
//      guard let name = $0?.replacingOccurrences(of: ":", with: "") else { return }
//      if !self.rename(originID: originID, name: name) {
//        NSAppModalAlert(title: Locale.renameTitle, prompt: Locale.renameFailed)
//      }
//    }
//  }
//
//  func showRenamePrompt(node: PatchNode) {
//    NSAppModalTextField(title: Locale.renameNodeTitle, prompt: Locale.renameNodePrompt) {
//      guard let name = $0?.replacingOccurrences(of: ":", with: "") else { return }
//      node.name = name
//      self.delegate?.didChangePatchNodes(self.nodes)
//      self.objectWillChange.send()
//    }
//  }
//
//  func showAddStreamPrompt(node: PatchNode) {
//    let values = [
//      PatchSocketID.StreamType.input.rawValue,
//      PatchSocketID.StreamType.output.rawValue
//    ]
//    NSAppModalTextFieldAndComboBox(
//      title: Locale.addStreamTitle,
//      prompt: Locale.addStreamPrompt,
//      defaultValue: PatchSocketID.StreamType.input.rawValue,
//      values: values) {
//        assert(Thread.isMainThread)
//        guard
//          let rawValue = $0,
//          let type = PatchSocketID.StreamType(rawValue: rawValue)
//        else {
//          return
//        }
//        let separator: String = ":"
//        var tag: String? = $1.isEmpty ? nil : $1
//        var index: Int? = nil
//        if $1.contains(separator) {
//          tag = $1.components(separatedBy:separator).first!
//          index = Int($1.components(separatedBy: separator).last ?? "")
//        }
//        var id: PatchSocketID!
//        if let tag = tag {
//          id = PatchSocketID(nodeID: node.id, type: type, tag: tag, index: index)
//        } else {
//          let lastIndex = (type == .input ? node.inputs : node.outputs).reduce(-1) {
//            guard $1.id.tag == nil else { return $0 }
//            return max($0, $1.id.index!)
//          }
//          id = PatchSocketID(nodeID: node.id, type: type, index: lastIndex + 1)
//        }
//        let socket = PatchSocket(id: id)
//        if (type == .input) {
//          node.inputs.append(socket)
//        } else {
//          node.outputs.append(socket)
//        }
//        self.delegate?.didChangePatchNodes(self.nodes)
//        self.objectWillChange.send()
//      }
//  }
//}
//
//
//import AppKit
//import SwiftUI
//
//extension EnvironmentValues {
//  public var patchStyle: PatchStyle {
//    get { self[PatchStyleKey.self] }
//    set { self[PatchStyleKey.self] = newValue }
//  }
//}
//
//private struct PatchStyleKey: EnvironmentKey {
//  typealias Value = PatchStyle
//  static var defaultValue: PatchStyle = DefaultPatchStyle()
//  static let style: String = "PatchStyleKey"
//}
//
//public protocol PatchStyle {
//  var grid: Color { get }
//  var background: LinearGradient { get }
//  var header: LinearGradient { get }
//  var foreground: Color { get }
//  var selected: Color { get }
//  var minimumSize: CGSize { get }
//  var cornerRadius: CGFloat { get }
//}
//
//public struct DefaultPatchStyle: PatchStyle {
//  public let grid: Color = Color(hex: 0x3C3C3C)
//  public let background: LinearGradient = LinearGradient(
//    colors: [Color(hex: 0x2E2F3A), Color(hex: 0x27292B)],
//    startPoint: .top,
//    endPoint: .bottom)
//  public let header: LinearGradient = LinearGradient(
//    colors: [Color(hex: 0x5C426F), Color(hex: 0x4E4C76)],
//    startPoint: .top,
//    endPoint: .bottom)
//  public let foreground: Color = Color(hex: 0xFFFFFF)
//  public let selected: Color = Color(hex: 0xE78944)
//  public let minimumSize: CGSize  = CGSize(width: 256, height: 192)
//  public let cornerRadius: CGFloat = 14
//}
//
//public struct QuartzComposerPatchStyle: PatchStyle {
//  public let grid: Color = Color(hex: 0x3C3C3C)
//  public let background: LinearGradient = LinearGradient(
//    colors: [Color(hex: 0x691168), Color(hex: 0x5E105D)],
//    startPoint: .top,
//    endPoint: .bottom)
//  public let header: LinearGradient = LinearGradient(
//    colors: [Color(hex: 0xA567A4), Color(hex: 0x7B2F7B)],
//    startPoint: .top,
//    endPoint: .bottom)
//  public let foreground: Color = Color(hex: 0xFFFFFF)
//  public let selected: Color = Color(hex: 0xFECB4C)
//  public let minimumSize: CGSize  = CGSize(width: 256, height: 192)
//  public let cornerRadius: CGFloat = 14
//}
//
//extension Color {
//  init(hex: UInt, alpha: Double = 1) {
//    self.init(
//      .sRGB,
//      red: Double((hex >> 16) & 0xff) / 255,
//      green: Double((hex >> 08) & 0xff) / 255,
//      blue: Double((hex >> 00) & 0xff) / 255,
//      opacity: alpha
//    )
//  }
//}
//
//extension NSColor {
//  convenience init(hex: UInt, alpha: CGFloat = 1) {
//    self.init(
//      red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
//      green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
//      blue: CGFloat(hex & 0x0000FF) / 255.0,
//      alpha: alpha
//    )
//  }
//}
//
//
