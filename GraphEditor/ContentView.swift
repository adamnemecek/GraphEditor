import SwiftUI

struct ContentView: View {

  @State var nodes: [PatchNode] = [testPatchIdx0(), testPatchIdx1()]

  var delegate: PatchEditorDelegate {
    PatchEditorDelegate {
//      print($0.adjacencyList)
      self.nodes = $0
    }
  }

    var body: some View {
      VStack {
        PatchEditor(nodes: nodes, delegate: delegate)
        Button("Add Node") {
          nodes.append(testPatchIdxNew())
        }
        Spacer()
      }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// TEST

var idx: Int = 0

func testPatchIdx0() -> PatchNode {
  let node = PatchNode(
    id: 0,
    name: "ForegroundMask",
    inputs: {
      $0.add(index: 0)
      $0.add(tag: "MODEL")
    },
    outputs: {
      $0.add(index: 0)
      $0.add(tag: "MASK", name: "mask")
        .addConnection(nodeID: 1, tag: "MASK")
    })
  idx += 1
  return node
}

func testPatchIdx1() -> PatchNode {
  let node = PatchNode(
    id: 1,
    name: "Compose",
    inputs: {
      $0.add(index: 0)
      $0.add(tag: "OVERLAY")
      $0.add(tag: "MASK")
    },
    outputs: {
      $0.add(index: 0)
  })
  idx += 1
  return node
}

func testPatchIdx2() -> PatchNode {
  let node = PatchNode(
    id: idx,
    name: "ColorCorrection",
    inputs: {
      $0.add(index: 0)
      $0.add(tag: "TONE", index: 0)
      $0.add(tag: "TONE", index: 1)
    },
    outputs: {
      $0.add(index: 0)
    })
  idx += 1
  return node
}

func testPatchIdxNew() -> PatchNode {
  let node = PatchNode(
    id: idx,
    name: "Undefined",
    inputs: { _ in
    },
    outputs: { _ in
    })
  idx += 1
  return node
}

import Foundation

enum Locale {
  // TODO: Adds l10n support.
  static var undefined: String { "undefined" }
  static var undefinedHelp: String { "The stream has not been named yet." }
  static var renameTitle: String { "Rename Stream" }
  static var renamePrompt: String { "Add a custom identifier for the selected stream." }
  static var renameFailed: String { "The stream name is already in use."}
  static var renameNodeTitle: String { "Set calculator name" }
  static var renameNodePrompt: String { "Set the calculator name for this node." }
  static var addStreamTitle: String { "Add new stream" }
  static var addStreamPrompt: String { "Add a new input/output stream for this node." }
  static var delete: String { "Delete" }
  static var rename: String { "Rename" }
  static var renameHelp: String { "Click to rename the stream." }
  static var inputs: String { "Input Streams" }
  static var outputs: String { "Output Streams" }
  static var noStreams: String { "No streams defined." }
  static var removeSocketHelp: String { "Remove the stream from this node." }
  static var settingsHelp: String { "Configure this node" }
  static var deleteHelp: String { "Remove this node" }
}

import SwiftUI

class PatchStore: ObservableObject {
  @Published var nodes: [PatchNode] = []
  @Published var selectedNodeID: Int?
  @Published var selectedConnection: PatchConnection? = nil
  var connections: [PatchSocketID: [PatchConnection]] { nodes.connections }
  var delegate: PatchEditorDelegate?

  // MARK: - Mutations

  func add(originID: PatchSocketID, destinationID: PatchSocketID) {
    assert(Thread.isMainThread)
    guard let (origin, _) = findSocketPair(
      originID: originID,
      destinationID: destinationID)
    else {
      // Could not find the sockets with the given IDs.
      return
    }
    guard
      !connections.values.flatMap({ $0 }).map({ $0.destinationID }).contains(destinationID)
    else {
      // The socket has already an attached stream.
      return
    }
    let connection = PatchConnection(originID: originID, destinationID: destinationID)
    guard delegate?.shouldAddConnection(connection) ?? true else {
      // The connection is not available.
      return
    }
    if origin.connections.contains(where: { $0.destinationID == destinationID }) { return }
    origin.addConnection(destinationID: destinationID)
    delegate?.didChangePatchNodes(nodes)
    objectWillChange.send()
  }

  func remove(originID: PatchSocketID, destinationID: PatchSocketID) {
    assert(Thread.isMainThread)
    guard let (origin, _) = findSocketPair(
      originID: originID,
      destinationID: destinationID)
    else {
      // Could not find the sockets with the given IDs.
      return
    }
    origin.connections = origin.connections.filter { $0.destinationID != destinationID }
    delegate?.didChangePatchNodes(nodes)
    objectWillChange.send()
  }

  @discardableResult
  func rename(originID: PatchSocketID, name: String) -> Bool {
    assert(Thread.isMainThread)
    let allOutputSockets = nodes.flatMap { $0.outputs }
    guard let socket = allOutputSockets.filter({ $0.id == originID }).first else {
      // Could not find the output socket with the given ID.
      return false
    }
    let names = Set<String>(allOutputSockets.compactMap { $0.name })
    guard !names.contains(name) else {
      // Names must me unique.
      return false
    }
    socket.name = name
    delegate?.didChangePatchNodes(nodes)
    objectWillChange.send()
    return true
  }

  func streamName(originID: PatchSocketID) -> String? {
    assert(Thread.isMainThread)
    guard let socket = nodes.flatMap({ $0.outputs }).filter({ $0.id == originID }).first else {
      return nil
    }
    return socket.name
  }

  func remove(node: PatchNode) {
    assert(Thread.isMainThread)
    for socket in node.outputs where !socket.connections.isEmpty {
      let originID = socket.id
      for destinationID in socket.connections {
        remove(originID: originID, destinationID: destinationID.destinationID)
      }
    }
    for (originID, destinations) in connections {
      for destination in destinations.filter({ $0.destinationID.nodeID == node.id }) {
        remove(originID: originID, destinationID: destination.destinationID)
      }
    }
    nodes = nodes.filter { $0.id != node.id }
    delegate?.didChangePatchNodes(nodes)
    objectWillChange.send()
  }

  func remove(socket: PatchSocket) {
    assert(Thread.isMainThread)
    guard let socketNode = nodes.first(where: { $0.id == socket.id.nodeID }) else {
      // Could not find the node with the given index.
      return
    }
    for node in nodes {
      for output in node.outputs {
        output.connections = output.connections.filter { $0.destinationID != socket.id }
      }
    }
    socketNode.inputs = socketNode.inputs.filter { $0.id != socket.id }
    socketNode.outputs = socketNode.outputs.filter { $0.id != socket.id }
    self.delegate?.didChangePatchNodes(self.nodes)
    self.objectWillChange.send()
  }


  // MARK: - Private

  private func findSocketPair(
    originID: PatchSocketID,
    destinationID: PatchSocketID
  ) -> (PatchSocket, PatchSocket)? {
    assert(Thread.isMainThread)
    let allInputSocket = nodes.flatMap { $0.inputs }
    let allOutputSockets = nodes.flatMap { $0.outputs }
    guard
      let origin = allOutputSockets.first(where: { $0.id == originID }),
      let destination = allInputSocket.first(where: { $0.id == destinationID })
    else {
      return nil
    }
    return (origin, destination)
  }

  // MARK: - Prompts

  func showRenamePrompt(originID: PatchSocketID) {
    NSAppModalTextField(title: Locale.renameTitle, prompt: Locale.renamePrompt) {
      guard let name = $0?.replacingOccurrences(of: ":", with: "") else { return }
      if !self.rename(originID: originID, name: name) {
        NSAppModalAlert(title: Locale.renameTitle, prompt: Locale.renameFailed)
      }
    }
  }

  func showRenamePrompt(node: PatchNode) {
    NSAppModalTextField(title: Locale.renameNodeTitle, prompt: Locale.renameNodePrompt) {
      guard let name = $0?.replacingOccurrences(of: ":", with: "") else { return }
      node.name = name
      self.delegate?.didChangePatchNodes(self.nodes)
      self.objectWillChange.send()
    }
  }

  func showAddStreamPrompt(node: PatchNode) {
    let values = [
      PatchSocketID.StreamType.input.rawValue,
      PatchSocketID.StreamType.output.rawValue
    ]
    NSAppModalTextFieldAndComboBox(
      title: Locale.addStreamTitle,
      prompt: Locale.addStreamPrompt,
      defaultValue: PatchSocketID.StreamType.input.rawValue,
      values: values) {
        assert(Thread.isMainThread)
        guard
          let rawValue = $0,
          let type = PatchSocketID.StreamType(rawValue: rawValue)
        else {
          return
        }
        let separator: String = ":"
        var tag: String? = $1.isEmpty ? nil : $1
        var index: Int? = nil
        if $1.contains(separator) {
          tag = $1.components(separatedBy:separator).first!
          index = Int($1.components(separatedBy: separator).last ?? "")
        }
        var id: PatchSocketID!
        if let tag = tag {
          id = PatchSocketID(nodeID: node.id, type: type, tag: tag, index: index)
        } else {
          let lastIndex = (type == .input ? node.inputs : node.outputs).reduce(-1) {
            guard $1.id.tag == nil else { return $0 }
            return max($0, $1.id.index!)
          }
          id = PatchSocketID(nodeID: node.id, type: type, index: lastIndex + 1)
        }
        let socket = PatchSocket(id: id)
        if (type == .input) {
          node.inputs.append(socket)
        } else {
          node.outputs.append(socket)
        }
        self.delegate?.didChangePatchNodes(self.nodes)
        self.objectWillChange.send()
      }
  }
}


import AppKit
import SwiftUI

extension EnvironmentValues {
  public var patchStyle: PatchStyle {
    get { self[PatchStyleKey.self] }
    set { self[PatchStyleKey.self] = newValue }
  }
}

private struct PatchStyleKey: EnvironmentKey {
  typealias Value = PatchStyle
  static var defaultValue: PatchStyle = DefaultPatchStyle()
  static let style: String = "PatchStyleKey"
}

public protocol PatchStyle {
  var grid: Color { get }
  var background: LinearGradient { get }
  var header: LinearGradient { get }
  var foreground: Color { get }
  var selected: Color { get }
  var minimumSize: CGSize { get }
  var cornerRadius: CGFloat { get }
}

public struct DefaultPatchStyle: PatchStyle {
  public let grid: Color = Color(hex: 0x3C3C3C)
  public let background: LinearGradient = LinearGradient(
    gradient: Gradient(colors: [Color(hex: 0x2E2F3A), Color(hex: 0x27292B)]),
    startPoint: .top,
    endPoint: .bottom)
  public let header: LinearGradient = LinearGradient(
    gradient: Gradient(colors: [Color(hex: 0x5C426F), Color(hex: 0x4E4C76)]),
    startPoint: .top,
    endPoint: .bottom)
  public let foreground: Color = Color(hex: 0xFFFFFF)
  public let selected: Color = Color(hex: 0xE78944)
  public let minimumSize: CGSize  = CGSize(width: 256, height: 192)
  public let cornerRadius: CGFloat = 14
}

public struct QuartzComposerPatchStyle: PatchStyle {
  public let grid: Color = Color(hex: 0x3C3C3C)
  public let background: LinearGradient = LinearGradient(
    gradient: Gradient(colors: [Color(hex: 0x691168), Color(hex: 0x5E105D)]),
    startPoint: .top,
    endPoint: .bottom)


  public let header: LinearGradient = LinearGradient(
    gradient: Gradient(colors: [Color(hex: 0xA567A4), Color(hex: 0x7B2F7B)]),
    startPoint: .top,
    endPoint: .bottom)
  public let foreground: Color = Color(hex: 0xFFFFFF)
  public let selected: Color = Color(hex: 0xFECB4C)
  public let minimumSize: CGSize  = CGSize(width: 256, height: 192)
  public let cornerRadius: CGFloat = 14
}

extension Color {
  init(hex: UInt, alpha: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xff) / 255,
      green: Double((hex >> 08) & 0xff) / 255,
      blue: Double((hex >> 00) & 0xff) / 255,
      opacity: alpha
    )
  }
}

extension NSColor {
  convenience init(hex: UInt, alpha: CGFloat = 1) {
    self.init(
      red: CGFloat((hex & 0xFF0000) >> 16) / 255.0,
      green: CGFloat((hex & 0x00FF00) >> 8) / 255.0,
      blue: CGFloat(hex & 0x0000FF) / 255.0,
      alpha: alpha
    )
  }
}

/// view internal


import AppKit

func NSAppBundle() -> Bundle { Bundle(identifier: "com.apple.AppKit")! }

func NSAppModalTextField(
  title: String,
  prompt: String,
  handler: @escaping (String?) -> Void
) {
  guard let window = NSApp.keyWindow else {
    handler(nil)
    return
  }
  let alert = NSAlert()
  alert.addButton(withTitle: NSAppBundle().localizedString(
    forKey: "Ok",
    value: nil,
    table: nil))
  alert.addButton(withTitle: NSAppBundle().localizedString(
    forKey: "Cancel",
    value: nil,
    table: nil))
  alert.messageText = title
  alert.informativeText = prompt
  let width = accessoryViewWidth
  let height = accessoryViewHeight
  let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: width, height: height))
  alert.accessoryView = textField
  alert.beginSheetModal(for: window) { response in
    guard response == .alertFirstButtonReturn else {
      handler(nil)
      return
    }
    handler(textField.stringValue)
  }
}

func NSAppModalTextFieldAndComboBox(
  title: String,
  prompt: String,
  defaultValue: String,
  values: [String],
  handler: @escaping (String?, String) -> Void
) {
  guard let window = NSApp.keyWindow else {
    handler(nil, "")
    return
  }
  let alert = NSAlert()
  alert.addButton(withTitle: NSAppBundle().localizedString(
    forKey: "Ok",
    value: nil,
    table: nil))
  alert.addButton(withTitle: NSAppBundle().localizedString(
    forKey: "Cancel",
    value: nil,
    table: nil))
  alert.messageText = title
  alert.informativeText = prompt
  let width = accessoryViewWidth
  let height = accessoryViewHeight
  let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: height))
  popup.addItems(withTitles: values)
  let textField = NSTextField(frame: NSRect(x: 0, y: height * 1.5, width: width, height: height))
  let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height * 2.5))
  accessoryView.addSubview(popup)
  accessoryView.addSubview(textField)
  alert.accessoryView = accessoryView
  alert.beginSheetModal(for: window) { response in
    guard response == .alertFirstButtonReturn else {
      handler(nil, "")
      return
    }
    handler(popup.selectedItem?.title ?? defaultValue, textField.stringValue)
  }
}

func NSAppModalAlert(title: String, prompt: String) {
  guard let window = NSApp.keyWindow else { return }
  let alert = NSAlert()
  alert.addButton(withTitle: NSAppBundle().localizedString(
    forKey: "Ok",
    value: nil,
    table: nil))
  alert.addButton(withTitle: NSAppBundle().localizedString(
    forKey: "Cancel",
    value: nil,
    table: nil))
  alert.messageText = title
  alert.informativeText = prompt
  alert.beginSheetModal(for: window) { _ in }
}

//private enum Constants {
  let accessoryViewWidth: CGFloat = 200
  let accessoryViewHeight: CGFloat = 24
//}


import SwiftUI

struct PatchLine: View {
  let fromID: PatchSocketID
  let toID: PatchSocketID?
  var to: CGPoint = .zero

  @State private var highlighted: Bool = false

  init(fromID: PatchSocketID, toID: PatchSocketID) {
    self.fromID = fromID
    self.toID = toID
  }

  init(fromID: PatchSocketID, to: CGPoint) {
    self.fromID = fromID
    self.toID = nil
    self.to = to
  }

  @Environment(\.patchStyle) var style: PatchStyle
  @EnvironmentObject private var store: PatchStore
  @EnvironmentObject private var geometry: PatchMeshGeometry

  private var patchConnection: PatchConnection? {
    guard let toID = toID else { return nil }
    return PatchConnection(originID: fromID, destinationID: toID)
  }
  private var isConnectionSelected: Bool {
    store.selectedConnection == patchConnection
  }

  var body: some View {
    ZStack {
      path
    }
  }

  private var path: some View {
    let fromPoint = geometry.point(for: fromID) ?? .zero
    let toPoint = geometry.point(for: toID) ?? to
    return PatchPath(
      from:fromPoint,
      to: toPoint,
      bounce: highlighted ? bounceMultiplier : idleBounceMultiplier)
      .stroke(isConnectionSelected ? style.selected : style.foreground, lineWidth: 4)
      .shadow(color: Color(hex: 0x000, alpha: 0.4), radius: 4, x: 0, y: 2)
      .contextMenu { contextMenu }
      .onTapGesture {
        store.selectedConnection = isConnectionSelected ? nil : patchConnection
        withAnimation(animation) {
          highlighted = isConnectionSelected
        }
      }
  }

  @ViewBuilder
  private var contextMenu: some View {
    if let toID = toID {
      Button(Locale.delete) { store.remove(originID: fromID, destinationID: toID) }
    }
    Button(Locale.rename) { store.showRenamePrompt(originID: fromID) }
  }

  private var animation: Animation {
    .interpolatingSpring(stiffness: 10, damping: 1, initialVelocity: 1)
  }
}

private struct PatchPath: Shape {
  let from: CGPoint
  let to: CGPoint
  var bounce: CGFloat

  var animatableData: CGFloat {
    get { bounce }
    set { bounce = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: from)

    var f = 0.3
    if (to.x > from.x) { f = 0.15 }
    if (abs(to.x - from.x) < straightLinePathThreshold) { f = 0.05 }

    let m = CGPoint(x: (to.x + from.x) * 0.5 , y: (to.y + from.y) * 0.5)
    let c1 = CGPoint(x: (CGFloat(f) * m.x + from.x) * bounce , y: from.y * bounce)
    let c2 = CGPoint(x: (to.x - CGFloat(f) * m.x) * bounce, y: to.y * bounce)

    path.addCurve(to: to, control1: c1, control2: c2)
    return path
  }
}

//private enum Constants {
   let straightLinePathThreshold: CGFloat = 150
   let idleBounceMultiplier: CGFloat = 1.0
   let bounceMultiplier: CGFloat = 1.05
//}

import SwiftUI

final class PatchMeshGeometry: ObservableObject {
  @Published var socketFrames: [PatchSocketID: CGRect] = [:]
  @Published var connectingSocket: (PatchSocketID, CGPoint)?
  @Published var meshContentSize: CGFloat = 0

  func point(for id: PatchSocketID?) -> CGPoint? {
    guard let id = id else { return nil }
    guard let frame = socketFrames[id] else { return .zero }
    let offset: CGFloat = socketCenterOffset
    return CGPoint(x: frame.origin.x + offset, y: frame.origin.y + offset)
  }

  func socketID(for point: CGPoint) -> PatchSocketID? {
    for (id, frame) in socketFrames {
      let targetFrame = frame.insetBy(dx: socketAnchorDx, dy: socketAnchorDy)
      let pointFrame = CGRect(origin: point, size: CGSize(width: 1, height: 1))
      if pointFrame.intersects(targetFrame) {
        return id
      }
    }
    return nil
  }
}

struct PatchMesh: View {
  @Environment(\.patchStyle) var style: PatchStyle
  @EnvironmentObject private var store: PatchStore
  @EnvironmentObject private var geometry: PatchMeshGeometry

  var body: some View {
    let connections = store.connections
    let origins = Array(connections.keys)
    Group {
      ForEach(origins) { fromID in
        ForEach(connections[fromID]!) { toID in
          PatchLine(fromID: fromID, toID: toID.destinationID)
        }
      }
      if let connectingSocket = geometry.connectingSocket {
        PatchLine(fromID: connectingSocket.0, to: connectingSocket.1)
      }
    }
    .drawingGroup()
  }
}

//private enum Constants {
   let socketCenterOffset: CGFloat = 6
   let socketAnchorDx: CGFloat = -40
  let socketAnchorDy: CGFloat = -10
//}


import SwiftUI

struct PatchSettings: View {
  let node: PatchNode

  @State private var position: CGPoint?

  @Environment(\.patchStyle) private var style: PatchStyle
  @EnvironmentObject private var store: PatchStore
  @EnvironmentObject private var geometry: PatchMeshGeometry

  var body: some View {
    VStack {
      inputStreams
      outputStreams
      divider
      addNewStream
      divider
      renameButton
    }
    .frame(maxWidth: .infinity)
    .padding([.top, .leading, .trailing])
  }

  private var divider: some View {
    Divider().background(style.foreground).opacity(0.2)
  }

  @ViewBuilder
  private var inputStreams: some View {
    Group {
      PatchText(Locale.inputs, bold: true)
      if node.inputs.isEmpty {
        PatchText(Locale.noStreams, bold: false, highlighted: false)
          .padding()
      } else {
        ForEach(node.inputs) { input in
          PatchSettingsInputStream(socket: input, node: node)
        }
      }
    }
  }

  @ViewBuilder
  private var outputStreams: some View {
    Group {
      PatchText(Locale.outputs, bold: true)
      if node.outputs.isEmpty {
        PatchText(Locale.noStreams, bold: false, highlighted: false)
          .padding()
      } else {
        ForEach(node.outputs) { output in
          PatchSettingsOutputStream(socket: output, node: node)
        }
      }
    }
  }

  @ViewBuilder
  private var addNewStream: some View {
    HStack {
      Button(action: showAddStreamPrompt) {
        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
          .font(.body.bold())
          .foregroundColor(style.foreground)
        PatchText(Locale.addStreamTitle, bold: true, highlighted: false)
      }
      .buttonStyle(BorderlessButtonStyle())
      .onHover(perform: onHoverButton)
      Spacer()
    }
  }

    @ViewBuilder
    private var renameButton: some View {
      HStack {
        Button(action: showRenamePrompt) {
          Image(systemName: "f.cursive")
            .font(.body.bold())
            .foregroundColor(style.foreground)
          PatchText(Locale.renameNodeTitle, bold: true, highlighted: false)
        }
        .buttonStyle(BorderlessButtonStyle())
        .onHover(perform: onHoverButton)
        Spacer()
      }
    }

  private func showAddStreamPrompt() {
    store.showAddStreamPrompt(node: node)
  }

  private func showRenamePrompt() {
    store.showRenamePrompt(node: node)
  }
}

private struct PatchSettingsOutputStream: View {
  let socket: PatchSocket
  let node: PatchNode

  @Environment(\.patchStyle) private var style: PatchStyle
  @EnvironmentObject private var store: PatchStore

  var body: some View {
    HStack {
      Spacer()
      PatchText(socket.id.label, bold: false, highlighted: false)
      Button(action: removeSocket) {
        removeSocketButtonLabel(style: style)
      }
      .buttonStyle(BorderlessButtonStyle())
    }
  }

  private func removeSocket() {
    store.remove(socket: socket)
  }
}

private struct PatchSettingsInputStream: View {
  let socket: PatchSocket
  let node: PatchNode

  @Environment(\.patchStyle) private var style: PatchStyle
  @EnvironmentObject private var store: PatchStore

  var body: some View {
    HStack {
      Button(action: removeSocket) {
        removeSocketButtonLabel(style: style)
      }
      .buttonStyle(BorderlessButtonStyle())
      PatchText(socket.id.label, bold: false, highlighted: false)
      Spacer()
    }
  }

  private func removeSocket() {
    store.remove(socket: socket)
  }
}

private func removeSocketButtonLabel(style: PatchStyle) -> some View {
  Image(systemName: "xmark")
    .font(.system(.caption).bold())
    .foregroundColor(style.foreground)
    .help(Locale.removeSocketHelp)
    .onHover(perform: onHoverButton)
}

private func onHoverButton(hover: Bool) {
  if hover {
    NSCursor.pointingHand.push()
  } else {
    NSCursor.pop()
  }
}


import SwiftUI

struct PatchInputSocketView: View {
  let node: PatchNode
  let id: PatchSocketID

  @Environment(\.patchStyle) var style: PatchStyle
  @EnvironmentObject private var store: PatchStore

  private var socket: PatchSocket {
    node.inputs.first { $0.id == id }!
  }
  private var isConnected: Bool {
    store.connections.values.flatMap { $0 }.map { $0.destinationID }.contains(id)
  }

  private var isSelected: Bool {
    guard
      let originID = store.selectedConnection?.originID,
      let destinationID = store.selectedConnection?.destinationID
    else {
      return false
    }
    return originID == id || destinationID == id
  }

  var body: some View {

    HStack(spacing: 0) {
      PatchSocketView(socket: socket, isConnected: isConnected, isSelected: isSelected)
        .padding([.trailing])
      PatchText(socket.id.label)
      Spacer()
    }
//    .padding(.leading, padding)
  }
}

struct PatchOutputSocketView: View {
  let node: PatchNode
  let id: PatchSocketID

  @Environment(\.patchStyle) var style: PatchStyle
  @EnvironmentObject private var geometry: PatchMeshGeometry
  @EnvironmentObject private var store: PatchStore

  private var socket: PatchSocket {
    node.outputs.first { $0.id == id }!
  }
  private var isConnected: Bool {
    !socket.connections.isEmpty
  }
  private var isSelected: Bool {
    guard
      let originID = store.selectedConnection?.originID,
      let destinationID = store.selectedConnection?.destinationID
    else {
      return false
    }
    return originID == id || destinationID == id
  }

  var body: some View {
    HStack(spacing: 0) {
      Spacer()
      PatchText(socket.id.label)
      PatchStreamName(socket: socket)
      PatchSocketView(socket: socket, isConnected: isConnected, isSelected: isSelected)
        .padding([.leading])
    }
//    .padding(.trailing, padding)
    .gesture(dragGesture)
  }

  private func mouseLocation(dragLocation: CGPoint) -> CGPoint {
    let nsPoint = NSEvent.mouseLocation
    let window = NSApplication.shared.mainWindow?.frame ?? .zero
    let point = CGPoint(
      x: dragLocation.x,
      y: window.size.height - nsPoint.y + window.minY - 30)
    return point
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named(PatchEditor.coordinateSpace))
      .onChanged {
        NSCursor.crosshair.push()
        let location = mouseLocation(dragLocation: $0.location)
        if let destinationID = geometry.socketID(for: location) {
          geometry.connectingSocket = (id, geometry.point(for: destinationID)!)
        } else {
          geometry.connectingSocket = (id, location)
        }
      }
      .onEnded {
        NSCursor.pop()
        let location = mouseLocation(dragLocation: $0.location)
        geometry.connectingSocket = nil
        if let destinationID = geometry.socketID(for: location) {
          store.add(originID: id, destinationID: destinationID)
        }
      }
  }
}

private struct PatchSocketView: View {
  let socket: PatchSocket
  let isConnected: Bool
  let isSelected: Bool

  @Environment(\.patchStyle) var style: PatchStyle
  @EnvironmentObject private var geometry: PatchMeshGeometry

  var body: some View {
    GeometryReader { geometryProxy in
      socketView(geometryProxy: geometryProxy)
    }
    .fixedSize()
  }

  private func socketView(geometryProxy: GeometryProxy) -> some View {
    let image = Image(systemName: isConnected ? "circle.fill" : "circle")
      .font(.caption.weight(.bold))
      .foregroundColor(isSelected ? style.selected : style.foreground)

    DispatchQueue.main.async {
      let coordinateSpace = PatchEditor.coordinateSpace
      let oldValue = self.geometry.socketFrames[socket.id]
      let newValue = geometryProxy.frame(in: .named(coordinateSpace))
      if (oldValue != newValue) {
        self.geometry.socketFrames[socket.id] = geometryProxy.frame(in: .named(coordinateSpace))
      }
    }
    return image
  }
}

//private enum Constants {
  let padding: CGFloat = 4
//}

import SwiftUI

struct PatchStreamName: View {
  let socket: PatchSocket

  @Environment(\.patchStyle) var style: PatchStyle
  @EnvironmentObject private var store: PatchStore

  private var isConnectionSelected: Bool {
    store.selectedConnection?.originID == socket.id
  }

  private var truncatedName: String {
    var name = socket.name ?? Locale.undefined
    let max = 35
    if name.lengthOfBytes(using: .utf8) > max {
      let index = name.index(name.startIndex, offsetBy: max)
      name = name.lengthOfBytes(using: .utf8) > max ? name.substring(to: index) + "…" : name
    }
    return ":" + name
  }

  var body: some View {
    if socket.id.type != .output || socket.connections.isEmpty {
      EmptyView()
    } else {
      HStack(spacing: 0) {
        Text(truncatedName)
          .patchTextStyle(style: style, bold: true, highlighted: isConnectionSelected)
          .onTapGesture { store.showRenamePrompt(originID: socket.id) }
          .help(Locale.renameHelp)
          .onHover(perform: onHover)
        if socket.name == nil {
          Image(systemName: "exclamationmark.circle.fill")
            .font(.system(.caption).bold())
            .foregroundColor(style.selected)
            .help(Locale.undefinedHelp)
        }
      }
    }
  }

  private func onHover(hover: Bool) {
    if hover {
      NSCursor.pointingHand.push()
    } else {
      NSCursor.pop()
    }
  }
}

import SwiftUI

struct PatchText: View {
  private let text: String
  private let bold: Bool
  private let highlighted: Bool

  @Environment(\.patchStyle) var style: PatchStyle

  init(_ verbatim: String, bold: Bool = false, highlighted: Bool = false) {
    self.text = verbatim
    self.bold = bold
    self.highlighted = highlighted
  }

  var body: some View {
    Text(verbatim: text).patchTextStyle(style: style, bold: bold, highlighted: highlighted)
  }
}

extension Text {
  func patchTextStyle(
    style: PatchStyle,
    bold: Bool = false,
    highlighted: Bool = false
  ) -> some View {
    self
      .font(Font.system(.caption, design: .rounded))
      .fontWeight(bold ? .bold : .regular)
      .foregroundColor(highlighted ? style.selected : style.foreground)
  }
}

import SwiftUI

struct PatchView: View {
  let node: PatchNode

  @State private var position: CGPoint?
  @State private var showSettings: Bool = false

  @Environment(\.patchStyle) private var style: PatchStyle
  @EnvironmentObject private var store: PatchStore
  @EnvironmentObject private var geometry: PatchMeshGeometry

  private var highlighted: Bool { store.selectedNodeID == node.id }

  var body: some View {
    GeometryReader { geometryReader in
      Group {
        if let position = position {
          contentView
            .position(x: position.x, y: position.y)
            .gesture(dragGesture)
        } else {
          contentView
            .gesture(dragGesture)
        }
      }.onAppear {
        let size = CGSize(
          width: style.minimumSize.width + gutter,
          height:  style.minimumSize.height + gutter)
        let maxRows = Int(geometryReader.size.height / size.height)
        let col = CGFloat(node.id / maxRows)
        let row = CGFloat(node.id % maxRows)

        let initialPosition = CGPoint(
          x: col * size.width + (size.width / 2),
          y: row * size.height + (size.height / 2) + gutter)

        position = initialPosition
        geometry.meshContentSize = max(geometry.meshContentSize, initialPosition.x + size.width * 2)
      }
    }
  }

  @ViewBuilder
  private var contentView: some View {
    VStack(alignment: .leading, spacing: 0) {
      headerView.frame(alignment: .top)
      if showSettings {
        settingsView
      } else {
        mainView
      }
    }
    .frame(maxWidth:style.minimumSize.width)
    .padding(.bottom)
    .background(style.background)
    .cornerRadius(style.cornerRadius)
    .roundedBorder(radius: style.cornerRadius, hidden: !highlighted, color: style.selected)
    .patchShadow()
    .onTapGesture {
      store.selectedNodeID = node.id
    }
  }

  @ViewBuilder
  private var mainView: some View {
    Group {
      groupedInputViews
      groupedOutputsViews
    }
  }

  @ViewBuilder
  private var settingsView: some View {
    Group {
      PatchSettings(node: node)
    }
  }

  private var headerView: some View {
    HStack {
      Image(systemName: "f.cursive")
        .font(.body.bold())
        .foregroundColor(style.foreground)
        .padding([.leading])
      PatchText(node.name, bold: true).frame(height: headerHeight)
      Spacer()
      Group {
        Divider().frame(height: headerHeight)
        Button(action: toggleSettings) {
          Image(systemName: "slider.vertical.3")
            .font(.body.weight(.black))
            .foregroundColor(style.foreground)
            .help(Locale.settingsHelp)
        }
        Divider().frame(height: headerHeight)
        Button(action: delete) {
          Image(systemName: "xmark")
            .font(.body.weight(.black))
            .foregroundColor(style.foreground)
            .padding(.trailing)
            .help(Locale.deleteHelp)
        }
      }
      .onHover(perform: onHoverButton)
      .buttonStyle(PlainButtonStyle())
    }
    .frame(maxWidth: .infinity, idealHeight:  headerHeight)
    .background(style.header)
  }

  private var groupedInputViews: some View {
    VStack {
      ForEach(node.inputs) {
        PatchInputSocketView(node: node, id: $0.id)
      }
    }
    .padding(.top)
  }

  private var groupedOutputsViews: some View {
    VStack {
      ForEach(node.outputs) {
        PatchOutputSocketView(node: node, id: $0.id)
      }
    }
    .padding(.top)
  }

  /// The gesture that handles the item being dragged on the screen.
  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged {
        guard !showSettings else { return }
        position = $0.location
      }
  }

  private func delete() {
    store.remove(node: node)
  }

  private func toggleSettings() {
    showSettings.toggle()
  }

  private func onHoverButton(hover: Bool) {
    if hover {
      NSCursor.pointingHand.push()
    } else {
      NSCursor.pop()
    }
  }
}

//private enum Constants {÷
   let gutter: CGFloat = 60
  let headerHeight: CGFloat = 36
//}


/// view public

import Foundation

/// A compact representation of the node with its input/output streams.
//public struct GraphAdjacencyListNode: Identifiable, Equatable, Hashable, CustomStringConvertible {
//  public let name: String
//  public let index: Int
//  public let inputs: [String]
//  public let outputs: [String]
//
//  public var id: Int { index }
//
//  public var description: String {
//    "\n[\(index)]: { name: \(name), inputs: \(inputs), outputs: \(outputs)}"
//  }
//}

extension Array where Element == PatchNode {
  /// Returns a compact graph represetation for the current states in the patch editor.
//  public var adjacencyList: [GraphAdjacencyListNode] {
//    let connections = connections
//
//    func streamTag(_ socketID: PatchSocketID) -> String {
//      if socketID.tag != nil {
//        return socketID.label + ":"
//      }
//      return ""
//    }
//
//    var result: [GraphAdjacencyListNode] = []
//    for node in self {
//      let inputConnections = connections.values
//        .flatMap { $0 }
//        .filter { $0.destinationID.nodeID == node.id }
//      let outputConnections = connections.values
//        .flatMap { $0 }
//        .filter { $0.originID.nodeID == node.id }
//
//      var inputs: [String] = []
//      for connection in inputConnections {
//        guard
//          let originNode = first(where: { $0.id == connection.originID.nodeID }),
//          let originSocket = originNode.outputs.first(where: { $0.id == connection.originID })
//        else {
//          continue
//        }
//        let input = streamTag(connection.destinationID) + originSocket.name
//        inputs.append(input)
//      }
//      var outputs: [String] = []
//      for connection in outputConnections {
//        guard
//          let originNode = first(where: { $0.id == connection.originID.nodeID }),
//          let originSocket = originNode.outputs.first(where: { $0.id == connection.originID })
//        else {
//          continue
//        }
//        let output = streamTag(connection.originID) + originSocket.name
//        outputs.append(output)
//      }
//      result.append(GraphAdjacencyListNode(
//        name: node.name,
//        index: node.id,
//        inputs: inputs.uniqued(),
//        outputs: outputs.uniqued()))
//    }
//    return result
//  }
}

extension Array where Element: Hashable {

  /// Removes all of the duplicated elements from this array.
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter{ seen.insert($0).inserted }
  }
}

import Foundation

public struct PatchSocketID: Identifiable, Equatable, Hashable {
  public enum StreamType: String {
    case input
    case output
  }

  public let nodeID: Int
  public let type: StreamType
  public let index: Int?
  public let tag: String?

  public init(nodeID: Int, type: StreamType, tag: String, index: Int? = nil) {
    self.nodeID = nodeID
    self.type = type
    self.tag = tag
    self.index = index
  }

  public init(nodeID: Int, type: StreamType, index: Int) {
    self.nodeID = nodeID
    self.type = type
    self.tag = nil
    self.index = index
  }

  /// Returns the name of this socket.
  public var label: String {
    var components: [String] = []
    if let tag = tag {
      components.append(tag)
    }
    if let index = index {
      components.append(String(index))
    }
    return components.joined(separator: ":")
  }

  /// Return the unique identifier for this socket.
  public var id: String { "\(nodeID)__\(type)__\(label)".replacingOccurrences(of: ":", with: "_") }

  public static func == (lhs: PatchSocketID, rhs: PatchSocketID) -> Bool { lhs.id == rhs.id }
}

/// Represents a input or output socket for a patch node.
public final class PatchSocket: Identifiable, Equatable {
  /// Synthesized stable key for this object.
  public let id: PatchSocketID
  /// Optional name (applicable only to output sockets).
  public var name: String

  var connections: [PatchConnection]

  init(id: PatchSocketID, connections: [PatchConnection] = [], name: String? = nil) {
    self.id = id
    self.connections = connections
    self.name = name ?? PatchSocket.newName()
  }

  @discardableResult
  public func addConnection(destinationID: PatchSocketID, name: String? = nil) -> PatchSocket {
    let connection = PatchConnection(
      originID: id,
      destinationID: destinationID)
    connections.append(connection)
    return self
  }

  /// Adds a connection to one of the inputs sockets for the specified node.
  @discardableResult
  public func addConnection(nodeID: Int, index: Int) -> PatchSocket {
    let connection = PatchConnection(
      originID: id,
      destinationID: PatchSocketID(nodeID: nodeID, type: .input, index: index))
    connections.append(connection)
    return self
  }

  /// Adds a connection to one of the inputs sockets for the specified node with the given tag.
  @discardableResult
  public func addConnection(
    nodeID: Int,
    tag: String,
    index: Int? = nil,
    name: String? = nil
  ) -> PatchSocket {
    let connection = PatchConnection(
      originID: id,
      destinationID: PatchSocketID(nodeID: nodeID, type: .input, tag: tag, index: index))
    connections.append(connection)
    return self
  }

  public static func == (lhs: PatchSocket, rhs: PatchSocket) -> Bool { lhs.id == rhs.id }

  private static var undefinedNameIndex: Int = 0
  private static func newName() -> String {
    undefinedNameIndex += 1
    return "undefined_\(undefinedNameIndex)"
  }
}

/// Represent a patch node.
open class PatchNode: Identifiable, Equatable, ObservableObject {
  /// Nodes are uniquely identified using their index.
  public let id: Int
  /// Represent the patch name (e.g. the name of the fuction associated to it).
  public var name: String
  /// Input streams sockets.
  @Published public var inputs: [PatchSocket]
  /// Output stream sockets.
  @Published public var outputs: [PatchSocket]

  public init(
    id: PatchNode.ID,
    name: String,
    inputs: (SocketBuilder) -> Void,
    outputs: (SocketBuilder) -> Void
  ) {
    self.id = id
    self.name = name
    let inputsBuilder = SocketBuilder(nodeID: id, type: .input)
    let outputsBuilder = SocketBuilder(nodeID: id, type: .output)
    inputs(inputsBuilder)
    outputs(outputsBuilder)
    self.inputs = inputsBuilder.sockets
    self.outputs = outputsBuilder.sockets
  }

  public static func == (lhs: PatchNode, rhs: PatchNode) -> Bool { lhs.id == rhs.id }
}

extension Array where Element == PatchNode {

  /// All of the connections in this mesh.
  public var connections: [PatchSocketID: [PatchConnection]] {
    let outputs: [PatchSocket] = reduce(into: []) {
      $0 = $0 + $1.outputs
    }
    var connections: [PatchSocketID: [PatchConnection]] = [:]
    for output in outputs where !output.connections.isEmpty {
      connections[output.id] = output.connections
    }
    return connections
  }
}

/// Represent an connection between two sockets in the mesh.
public final class PatchConnection: Identifiable, Equatable {
  public let originID: PatchSocketID
  public let destinationID: PatchSocketID

  init(originID: PatchSocketID, destinationID: PatchSocketID) {
    self.originID = originID
    self.destinationID = destinationID
  }

  public var id: String { originID.id + "_" + destinationID.id }

  public static func == (lhs: PatchConnection, rhs: PatchConnection) -> Bool { lhs.id == rhs.id }
}

// MARK: - Builders.

public final class SocketBuilder {
  private let nodeID: Int
  private let type: PatchSocketID.StreamType
  var sockets: [PatchSocket] = []

  init(nodeID: Int, type: PatchSocketID.StreamType) {
    self.nodeID = nodeID
    self.type = type
  }

  @discardableResult
  public func add(index: Int, name: String? = nil) -> PatchSocket {
    let socket = PatchSocket(
      id: PatchSocketID(nodeID: nodeID, type: type, index: index),
      name: name)
    sockets.append(socket)
    return socket
  }

  @discardableResult
  public func add(tag: String, index: Int? = nil, name: String? = nil) -> PatchSocket {
    let socket = PatchSocket(
      id: PatchSocketID(nodeID: nodeID, type: type, tag: tag, index: index),
      name: name)
    sockets.append(socket)
    return socket
  }
}


import SwiftUI

public struct PatchEditor: View {
  /// The nodes that will be displayed in the mesh.
  public let nodes: [PatchNode]

  /// Callbacks executed whenever the editor has performed a change on the mesh.
  public let delegate: PatchEditorDelegate?

  @State private var panOFfset: CGSize = .zero

  @Environment(\.patchStyle) public var style: PatchStyle
  @StateObject private var geometry: PatchMeshGeometry = .init()
  @StateObject private var store: PatchStore = .init()

  static let coordinateSpace: String = #file

  public var body: some View {
    ScrollView(.horizontal) {
      ZStack {
        PatchMesh()
        ForEach(store.nodes) { node in
          PatchView(node: node)
        }
      }
      .frame(
        minWidth: geometry.meshContentSize,
        maxWidth: .infinity,
        maxHeight: .infinity)
      .background(style.grid)
      .coordinateSpace(name: PatchEditor.coordinateSpace)
      .offset(panOFfset)
      .environmentObject(store)
      .environmentObject(geometry)
      .onAppear { updateStore() }
      .onChange(of: nodes) { updateStore(nodes: $0) }
    }
  }

  private func updateStore(nodes newNodes: [PatchNode]? = nil) {
    store.delegate = delegate
    store.nodes = newNodes ?? nodes
  }
}

import SwiftUI

public struct PatchEditorDelegate {
  /// Callback called whenever anything has changed in the nodes collection.
  /// Use the other delegate methods to have fine grain control over what has changed.
  public let didChangePatchNodes: ([PatchNode]) -> Void

  /// Whether a connection from the first to the second socket is possible.
  public let shouldAddConnection: (PatchConnection) -> Bool

  public init(
    shouldAddConnection: @escaping (PatchConnection) -> Bool = { _ in true },
    didChangePatchNodes: @escaping ([PatchNode]) -> Void = { _ in }
  ) {
    self.shouldAddConnection = shouldAddConnection
    self.didChangePatchNodes = didChangePatchNodes
  }
}


/// extension
import Foundation
import CoreGraphics

public extension Float {
  /// Returns a random floating point number between 0.0 and 1.0, inclusive.
  static var random: Float {
    Float(arc4random()) / 0xFFFFFFFF
  }

  /// Random float between 0 and n-1.
  ///
  /// - parameter n:  Interval max
  /// - returns: Returns a random float point number between 0 and n max
  static func random(min: Float, max: Float) -> Float {
    Float.random * (max - min) + min
  }
}

public extension CGFloat {
  /// Randomly returns either 1.0 or -1.0.
  static var randomSign: CGFloat {
    (arc4random_uniform(2) == 0) ? 1.0 : -1.0
  }

  /// Returns a random floating point number between 0.0 and 1.0, inclusive.
  static var random: CGFloat {
    CGFloat(Float.random)
  }

  /// Random CGFloat between 0 and n-1.
  ///
  /// - parameter n:  Interval max
  /// - returns: A random CGFloat point number between 0 and n max
  static func random(min: CGFloat, max: CGFloat) -> CGFloat {
    CGFloat.random * (max - min) + min
  }
}


import SwiftUI

extension View {
  /// The radius to use when drawing rounded corners for the view background.
  func cornerRadius(_ radius: CGFloat) -> some View {
    clipShape(RoundedRectangle.init(cornerRadius: radius, style: .circular))
  }

  /// Applies the default box shadow for the patch nodes.
  func patchShadow() -> some View {
    shadow(color: Color(hex: 0x000, alpha: 0.2), radius: 4, x: 0, y: 2)
  }

  /// Adds an rounded rectangle overlay to the view.
  func roundedBorder(radius: CGFloat, hidden: Bool = false, color: Color) -> some View {
    overlay(RoundedRectangle(cornerRadius: radius).stroke(color, lineWidth: hidden ? 0 : 2))
  }

  /// Applies the given transform if the given condition evaluates to `true`.
  /// - parameter condition: The condition to evaluate.
  /// - parameter transform: The transform to apply to the source `View`.
  /// - returns: Either the original `View` or the modified `View` if the condition is `true`.
  @ViewBuilder
  func when<C: View>(_ condition: Bool, transform: (Self) -> C) -> some View {
    if condition {
        transform(self)
      } else {
        self
      }
    }
}

