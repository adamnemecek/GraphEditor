//import AppKit
//
//func NSAppBundle() -> Bundle { Bundle(identifier: "com.apple.AppKit")! }
//
//func NSAppModalTextField(
//  title: String,
//  prompt: String,
//  handler: @escaping (String?) -> Void
//) {
//  guard let window = NSApp.keyWindow else {
//    handler(nil)
//    return
//  }
//  let alert = NSAlert()
//  alert.addButton(withTitle: NSAppBundle().localizedString(
//    forKey: "Ok",
//    value: nil,
//    table: nil))
//  alert.addButton(withTitle: NSAppBundle().localizedString(
//    forKey: "Cancel",
//    value: nil,
//    table: nil))
//  alert.messageText = title
//  alert.informativeText = prompt
//  let width = Constants.accessoryViewWidth
//  let height = Constants.accessoryViewHeight
//  let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: width, height: height))
//  alert.accessoryView = textField
//  alert.beginSheetModal(for: window) { response in
//    guard response == .alertFirstButtonReturn else {
//      handler(nil)
//      return
//    }
//    handler(textField.stringValue)
//  }
//}
//
//func NSAppModalTextFieldAndComboBox(
//  title: String,
//  prompt: String,
//  defaultValue: String,
//  values: [String],
//  handler: @escaping (String?, String) -> Void
//) {
//  guard let window = NSApp.keyWindow else {
//    handler(nil, "")
//    return
//  }
//  let alert = NSAlert()
//  alert.addButton(withTitle: NSAppBundle().localizedString(
//    forKey: "Ok",
//    value: nil,
//    table: nil))
//  alert.addButton(withTitle: NSAppBundle().localizedString(
//    forKey: "Cancel",
//    value: nil,
//    table: nil))
//  alert.messageText = title
//  alert.informativeText = prompt
//  let width = Constants.accessoryViewWidth
//  let height = Constants.accessoryViewHeight
//  let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: height))
//  popup.addItems(withTitles: values)
//  let textField = NSTextField(frame: NSRect(x: 0, y: height * 1.5, width: width, height: height))
//  let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height * 2.5))
//  accessoryView.addSubview(popup)
//  accessoryView.addSubview(textField)
//  alert.accessoryView = accessoryView
//  alert.beginSheetModal(for: window) { response in
//    guard response == .alertFirstButtonReturn else {
//      handler(nil, "")
//      return
//    }
//    handler(popup.selectedItem?.title ?? defaultValue, textField.stringValue)
//  }
//}
//
//func NSAppModalAlert(title: String, prompt: String) {
//  guard let window = NSApp.keyWindow else { return }
//  let alert = NSAlert()
//  alert.addButton(withTitle: NSAppBundle().localizedString(
//    forKey: "Ok",
//    value: nil,
//    table: nil))
//  alert.addButton(withTitle: NSAppBundle().localizedString(
//    forKey: "Cancel",
//    value: nil,
//    table: nil))
//  alert.messageText = title
//  alert.informativeText = prompt
//  alert.beginSheetModal(for: window) { _ in }
//}
//
//private enum Constants {
//  static let accessoryViewWidth: CGFloat = 200
//  static let accessoryViewHeight: CGFloat = 24
//}
//
//
//import SwiftUI
//
//struct PatchLine: View {
//  let fromID: PatchSocketID
//  let toID: PatchSocketID?
//  var to: CGPoint = .zero
//
//  @State private var highlighted: Bool = false
//
//  init(fromID: PatchSocketID, toID: PatchSocketID) {
//    self.fromID = fromID
//    self.toID = toID
//  }
//
//  init(fromID: PatchSocketID, to: CGPoint) {
//    self.fromID = fromID
//    self.toID = nil
//    self.to = to
//  }
//
//  @Environment(\.patchStyle) var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//  @EnvironmentObject private var geometry: PatchMeshGeometry
//
//  private var patchConnection: PatchConnection? {
//    guard let toID = toID else { return nil }
//    return PatchConnection(originID: fromID, destinationID: toID)
//  }
//  private var isConnectionSelected: Bool {
//    store.selectedConnection == patchConnection
//  }
//
//  var body: some View {
//    ZStack {
//      path
//    }
//  }
//
//  private var path: some View {
//    let fromPoint = geometry.point(for: fromID) ?? .zero
//    let toPoint = geometry.point(for: toID) ?? to
//    return PatchPath(
//      from:fromPoint,
//      to: toPoint,
//      bounce: highlighted ? Constants.bounceMultiplier : Constants.idleBounceMultiplier)
//      .stroke(isConnectionSelected ? style.selected : style.foreground, lineWidth: 4)
//      .shadow(color: Color(hex: 0x000, alpha: 0.4), radius: 4, x: 0, y: 2)
//      .contextMenu { contextMenu }
//      .onTapGesture {
//        store.selectedConnection = isConnectionSelected ? nil : patchConnection
//        withAnimation(animation) {
//          highlighted = isConnectionSelected
//        }
//      }
//  }
//
//  @ViewBuilder
//  private var contextMenu: some View {
//    if let toID = toID {
//      Button(Locale.delete) { store.remove(originID: fromID, destinationID: toID) }
//    }
//    Button(Locale.rename) { store.showRenamePrompt(originID: fromID) }
//  }
//
//  private var animation: Animation {
//    .interpolatingSpring(stiffness: 10, damping: 1, initialVelocity: 1)
//  }
//}
//
//private struct PatchPath: Shape {
//  let from: CGPoint
//  let to: CGPoint
//  var bounce: CGFloat
//
//  var animatableData: CGFloat {
//    get { bounce }
//    set { bounce = newValue }
//  }
//
//  func path(in rect: CGRect) -> Path {
//    var path = Path()
//    path.move(to: from)
//
//    var f = 0.3
//    if (to.x > from.x) { f = 0.15 }
//    if (abs(to.x - from.x) < Constants.straightLinePathThreshold) { f = 0.05 }
//
//    let m = CGPoint(x: (to.x + from.x) * 0.5 , y: (to.y + from.y) * 0.5)
//    let c1 = CGPoint(x: (f * m.x + from.x) * bounce , y: from.y * bounce)
//    let c2 = CGPoint(x: (to.x - f * m.x) * bounce, y: to.y * bounce)
//
//    path.addCurve(to: to, control1: c1, control2: c2)
//    return path
//  }
//}
//
//private enum Constants {
//  static let straightLinePathThreshold: CGFloat = 150
//  static let idleBounceMultiplier: CGFloat = 1.0
//  static let bounceMultiplier: CGFloat = 1.05
//}
//
//import SwiftUI
//
//final class PatchMeshGeometry: ObservableObject {
//  @Published var socketFrames: [PatchSocketID: CGRect] = [:]
//  @Published var connectingSocket: (PatchSocketID, CGPoint)?
//  @Published var meshContentSize: CGFloat = 0
//
//  func point(for id: PatchSocketID?) -> CGPoint? {
//    guard let id = id else { return nil }
//    guard let frame = socketFrames[id] else { return .zero }
//    let offset: CGFloat = Constants.socketCenterOffset
//    return CGPoint(x: frame.origin.x + offset, y: frame.origin.y + offset)
//  }
//
//  func socketID(for point: CGPoint) -> PatchSocketID? {
//    for (id, frame) in socketFrames {
//      let targetFrame = frame.insetBy(dx: Constants.socketAnchorDx, dy: Constants.socketAnchorDy)
//      let pointFrame = CGRect(origin: point, size: CGSize(width: 1, height: 1))
//      if pointFrame.intersects(targetFrame) {
//        return id
//      }
//    }
//    return nil
//  }
//}
//
//struct PatchMesh: View {
//  @Environment(\.patchStyle) var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//  @EnvironmentObject private var geometry: PatchMeshGeometry
//
//  var body: some View {
//    let connections = store.connections
//    let origins = Array(connections.keys)
//    Group {
//      ForEach(origins) { fromID in
//        ForEach(connections[fromID]!) { toID in
//          PatchLine(fromID: fromID, toID: toID.destinationID)
//        }
//      }
//      if let connectingSocket = geometry.connectingSocket {
//        PatchLine(fromID: connectingSocket.0, to: connectingSocket.1)
//      }
//    }
//    .drawingGroup()
//  }
//}
//
//private enum Constants {
//  static let socketCenterOffset: CGFloat = 6
//  static let socketAnchorDx: CGFloat = -40
//  static let socketAnchorDy: CGFloat = -10
//}
//
//
//import SwiftUI
//
//struct PatchSettings: View {
//  let node: PatchNode
//
//  @State private var position: CGPoint?
//
//  @Environment(\.patchStyle) private var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//  @EnvironmentObject private var geometry: PatchMeshGeometry
//
//  var body: some View {
//    VStack {
//      inputStreams
//      outputStreams
//      divider
//      addNewStream
//      divider
//      renameButton
//    }
//    .frame(maxWidth: .infinity)
//    .padding([.top, .leading, .trailing])
//  }
//
//  private var divider: some View {
//    Divider().background(style.foreground).opacity(0.2)
//  }
//
//  @ViewBuilder
//  private var inputStreams: some View {
//    Group {
//      PatchText(Locale.inputs, bold: true)
//      if node.inputs.isEmpty {
//        PatchText(Locale.noStreams, bold: false, highlighted: false)
//          .padding()
//      } else {
//        ForEach(node.inputs) { input in
//          PatchSettingsInputStream(socket: input, node: node)
//        }
//      }
//    }
//  }
//
//  @ViewBuilder
//  private var outputStreams: some View {
//    Group {
//      PatchText(Locale.outputs, bold: true)
//      if node.outputs.isEmpty {
//        PatchText(Locale.noStreams, bold: false, highlighted: false)
//          .padding()
//      } else {
//        ForEach(node.outputs) { output in
//          PatchSettingsOutputStream(socket: output, node: node)
//        }
//      }
//    }
//  }
//
//  @ViewBuilder
//  private var addNewStream: some View {
//    HStack {
//      Button(action: showAddStreamPrompt) {
//        Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
//          .font(.body.bold())
//          .foregroundColor(style.foreground)
//        PatchText(Locale.addStreamTitle, bold: true, highlighted: false)
//      }
//      .buttonStyle(.borderless)
//      .onHover(perform: onHoverButton)
//      Spacer()
//    }
//  }
//
//    @ViewBuilder
//    private var renameButton: some View {
//      HStack {
//        Button(action: showRenamePrompt) {
//          Image(systemName: "f.cursive")
//            .font(.body.bold())
//            .foregroundColor(style.foreground)
//          PatchText(Locale.renameNodeTitle, bold: true, highlighted: false)
//        }
//        .buttonStyle(.borderless)
//        .onHover(perform: onHoverButton)
//        Spacer()
//      }
//    }
//
//  private func showAddStreamPrompt() {
//    store.showAddStreamPrompt(node: node)
//  }
//
//  private func showRenamePrompt() {
//    store.showRenamePrompt(node: node)
//  }
//}
//
//private struct PatchSettingsOutputStream: View {
//  let socket: PatchSocket
//  let node: PatchNode
//
//  @Environment(\.patchStyle) private var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//
//  var body: some View {
//    HStack {
//      Spacer()
//      PatchText(socket.id.label, bold: false, highlighted: false)
//      Button(action: removeSocket) {
//        removeSocketButtonLabel(style: style)
//      }
//      .buttonStyle(.borderless)
//    }
//  }
//
//  private func removeSocket() {
//    store.remove(socket: socket)
//  }
//}
//
//private struct PatchSettingsInputStream: View {
//  let socket: PatchSocket
//  let node: PatchNode
//
//  @Environment(\.patchStyle) private var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//
//  var body: some View {
//    HStack {
//      Button(action: removeSocket) {
//        removeSocketButtonLabel(style: style)
//      }
//      .buttonStyle(.borderless)
//      PatchText(socket.id.label, bold: false, highlighted: false)
//      Spacer()
//    }
//  }
//
//  private func removeSocket() {
//    store.remove(socket: socket)
//  }
//}
//
//private func removeSocketButtonLabel(style: PatchStyle) -> some View {
//  Image(systemName: "xmark")
//    .font(.system(.caption).bold())
//    .foregroundColor(style.foreground)
//    .help(Locale.removeSocketHelp)
//    .onHover(perform: onHoverButton)
//}
//
//private func onHoverButton(hover: Bool) {
//  if hover {
//    NSCursor.pointingHand.push()
//  } else {
//    NSCursor.pop()
//  }
//}
//
//
//import SwiftUI
//
//struct PatchInputSocketView: View {
//  let node: PatchNode
//  let id: PatchSocketID
//
//  @Environment(\.patchStyle) var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//
//  private var socket: PatchSocket {
//    node.inputs.first { $0.id == id }!
//  }
//  private var isConnected: Bool {
//    store.connections.values.flatMap { $0 }.map { $0.destinationID }.contains(id)
//  }
//
//  private var isSelected: Bool {
//    guard
//      let originID = store.selectedConnection?.originID,
//      let destinationID = store.selectedConnection?.destinationID
//    else {
//      return false
//    }
//    return originID == id || destinationID == id
//  }
//
//  var body: some View {
//    HStack(spacing: 0) {
//      PatchStocketView(socket: socket, isConnected: isConnected, isSelected: isSelected)
//        .padding([.trailing])
//      PatchText(socket.id.label)
//      Spacer()
//    }
//    .padding(.leading, Constants.padding)
//  }
//}
//
//struct PatchOutputSocketView: View {
//  let node: PatchNode
//  let id: PatchSocketID
//
//  @Environment(\.patchStyle) var style: PatchStyle
//  @EnvironmentObject private var geometry: PatchMeshGeometry
//  @EnvironmentObject private var store: PatchStore
//
//  private var socket: PatchSocket {
//    node.outputs.first { $0.id == id }!
//  }
//  private var isConnected: Bool {
//    !socket.connections.isEmpty
//  }
//  private var isSelected: Bool {
//    guard
//      let originID = store.selectedConnection?.originID,
//      let destinationID = store.selectedConnection?.destinationID
//    else {
//      return false
//    }
//    return originID == id || destinationID == id
//  }
//
//  var body: some View {
//    HStack(spacing: 0) {
//      Spacer()
//      PatchText(socket.id.label)
//      PatchStreamName(socket: socket)
//      PatchStocketView(socket: socket, isConnected: isConnected, isSelected: isSelected)
//        .padding([.leading])
//    }
//    .padding(.trailing, Constants.padding)
//    .gesture(dragGesture)
//  }
//
//  private func mouseLocation(dragLocation: CGPoint) -> CGPoint {
//    let nsPoint = NSEvent.mouseLocation
//    let window = NSApplication.shared.mainWindow?.frame ?? .zero
//    let point = CGPoint(
//      x: dragLocation.x,
//      y: window.size.height - nsPoint.y + window.minY - 30)
//    return point
//  }
//
//  private var dragGesture: some Gesture {
//    DragGesture(minimumDistance: 0, coordinateSpace: .named(PatchEditor.coordinateSpace))
//      .onChanged {
//        NSCursor.crosshair.push()
//        let location = mouseLocation(dragLocation: $0.location)
//        if let destinationID = geometry.socketID(for: location) {
//          geometry.connectingSocket = (id, geometry.point(for: destinationID)!)
//        } else {
//          geometry.connectingSocket = (id, location)
//        }
//      }
//      .onEnded {
//        NSCursor.pop()
//        let location = mouseLocation(dragLocation: $0.location)
//        geometry.connectingSocket = nil
//        if let destinationID = geometry.socketID(for: location) {
//          store.add(originID: id, destinationID: destinationID)
//        }
//      }
//  }
//}
//
//private struct PatchStocketView: View {
//  let socket: PatchSocket
//  let isConnected: Bool
//  let isSelected: Bool
//
//  @Environment(\.patchStyle) var style: PatchStyle
//  @EnvironmentObject private var geometry: PatchMeshGeometry
//
//  var body: some View {
//    GeometryReader { geometryProxy in
//      socketView(geometryProxy: geometryProxy)
//    }
//    .fixedSize()
//  }
//
//  private func socketView(geometryProxy: GeometryProxy) -> some View {
//    let image = Image(systemName: isConnected ? "circle.fill" : "circle")
//      .font(.caption.weight(.bold))
//      .foregroundColor(isSelected ? style.selected : style.foreground)
//
//    DispatchQueue.main.async {
//      let coordinateSpace = PatchEditor.coordinateSpace
//      let oldValue = self.geometry.socketFrames[socket.id]
//      let newValue = geometryProxy.frame(in: .named(coordinateSpace))
//      if (oldValue != newValue) {
//        self.geometry.socketFrames[socket.id] = geometryProxy.frame(in: .named(coordinateSpace))
//      }
//    }
//    return image
//  }
//}
//
//private enum Constants {
//  static let padding: CGFloat = 4
//}
//
//import SwiftUI
//
//struct PatchStreamName: View {
//  let socket: PatchSocket
//
//  @Environment(\.patchStyle) var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//
//  private var isConnectionSelected: Bool {
//    store.selectedConnection?.originID == socket.id
//  }
//
//  private var truncatedName: String {
//    var name = socket.name ?? Locale.undefined
//    let max = 35
//    if name.lengthOfBytes(using: .utf8) > max {
//      let index = name.index(name.startIndex, offsetBy: max)
//      name = name.lengthOfBytes(using: .utf8) > max ? name.substring(to: index) + "…" : name
//    }
//    return ":" + name
//  }
//
//  var body: some View {
//    if socket.id.type != .output || socket.connections.isEmpty {
//      EmptyView()
//    } else {
//      HStack(spacing: 0) {
//        Text(truncatedName)
//          .patchTextStyle(style: style, bold: true, highlighted: isConnectionSelected)
//          .onTapGesture { store.showRenamePrompt(originID: socket.id) }
//          .help(Locale.renameHelp)
//          .onHover(perform: onHover)
//        if socket.name == nil {
//          Image(systemName: "exclamationmark.circle.fill")
//            .font(.system(.caption).bold())
//            .foregroundColor(style.selected)
//            .help(Locale.undefinedHelp)
//        }
//      }
//    }
//  }
//
//  private func onHover(hover: Bool) {
//    if hover {
//      NSCursor.pointingHand.push()
//    } else {
//      NSCursor.pop()
//    }
//  }
//}
//
//import SwiftUI
//
//struct PatchText: View {
//  private let text: String
//  private let bold: Bool
//  private let highlighted: Bool
//
//  @Environment(\.patchStyle) var style: PatchStyle
//
//  init(_ verbatim: String, bold: Bool = false, highlighted: Bool = false) {
//    self.text = verbatim
//    self.bold = bold
//    self.highlighted = highlighted
//  }
//
//  var body: some View {
//    Text(verbatim: text).patchTextStyle(style: style, bold: bold, highlighted: highlighted)
//  }
//}
//
//extension Text {
//  func patchTextStyle(
//    style: PatchStyle,
//    bold: Bool = false,
//    highlighted: Bool = false
//  ) -> some View {
//    self
//      .font(Font.system(.caption, design: .rounded))
//      .fontWeight(bold ? .bold : .regular)
//      .foregroundColor(highlighted ? style.selected : style.foreground)
//  }
//}
//
//import SwiftUI
//
//struct PatchView: View {
//  let node: PatchNode
//
//  @State private var position: CGPoint?
//  @State private var showSettings: Bool = false
//
//  @Environment(\.patchStyle) private var style: PatchStyle
//  @EnvironmentObject private var store: PatchStore
//  @EnvironmentObject private var geometry: PatchMeshGeometry
//
//  private var highlighted: Bool { store.selectedNodeID == node.id }
//
//  var body: some View {
//    GeometryReader { geometryReader in
//      Group {
//        if let position = position {
//          contentView
//            .position(x: position.x, y: position.y)
//            .gesture(dragGesture)
//        } else {
//          contentView
//            .gesture(dragGesture)
//        }
//      }.onAppear {
//        let size = CGSize(
//          width: style.minimumSize.width + Constants.gutter,
//          height:  style.minimumSize.height + Constants.gutter)
//        let maxRows = Int(geometryReader.size.height / size.height)
//        let col = CGFloat(node.id / maxRows)
//        let row = CGFloat(node.id % maxRows)
//
//        let initialPosition = CGPoint(
//          x: col * size.width + (size.width / 2),
//          y: row * size.height + (size.height / 2) + Constants.gutter)
//
//        position = initialPosition
//        geometry.meshContentSize = max(geometry.meshContentSize, initialPosition.x + size.width * 2)
//      }
//    }
//  }
//
//  @ViewBuilder
//  private var contentView: some View {
//    VStack(alignment: .leading, spacing: 0) {
//      headerView.frame(alignment: .top)
//      if showSettings {
//        settingsView
//      } else {
//        mainView
//      }
//    }
//    .frame(maxWidth:style.minimumSize.width)
//    .padding(.bottom)
//    .background(style.background)
//    .cornerRadius(style.cornerRadius)
//    .roundedBorder(radius: style.cornerRadius, hidden: !highlighted, color: style.selected)
//    .patchShadow()
//    .onTapGesture {
//      store.selectedNodeID = node.id
//    }
//  }
//
//  @ViewBuilder
//  private var mainView: some View {
//    Group {
//      groupedInputViews
//      groupedOutputsViews
//    }
//  }
//
//  @ViewBuilder
//  private var settingsView: some View {
//    Group {
//      PatchSettings(node: node)
//    }
//  }
//
//  private var headerView: some View {
//    HStack {
//      Image(systemName: "f.cursive")
//        .font(.body.bold())
//        .foregroundColor(style.foreground)
//        .padding([.leading])
//      PatchText(node.name, bold: true).frame(height: Constants.headerHeight)
//      Spacer()
//      Group {
//        Divider().frame(height: Constants.headerHeight)
//        Button(action: toggleSettings) {
//          Image(systemName: "slider.vertical.3")
//            .font(.body.weight(.black))
//            .foregroundColor(style.foreground)
//            .help(Locale.settingsHelp)
//        }
//        Divider().frame(height: Constants.headerHeight)
//        Button(action: delete) {
//          Image(systemName: "xmark")
//            .font(.body.weight(.black))
//            .foregroundColor(style.foreground)
//            .padding(.trailing)
//            .help(Locale.deleteHelp)
//        }
//      }
//      .onHover(perform: onHoverButton)
//      .buttonStyle(.plain)
//    }
//    .frame(maxWidth: .infinity, idealHeight:  Constants.headerHeight)
//    .background(style.header)
//  }
//
//  private var groupedInputViews: some View {
//    VStack {
//      ForEach(node.inputs) {
//        PatchInputSocketView(node: node, id: $0.id)
//      }
//    }
//    .padding(.top)
//  }
//
//  private var groupedOutputsViews: some View {
//    VStack {
//      ForEach(node.outputs) {
//        PatchOutputSocketView(node: node, id: $0.id)
//      }
//    }
//    .padding(.top)
//  }
//
//  /// The gesture that handles the item being dragged on the screen.
//  private var dragGesture: some Gesture {
//    DragGesture()
//      .onChanged {
//        guard !showSettings else { return }
//        position = $0.location
//      }
//  }
//
//  private func delete() {
//    store.remove(node: node)
//  }
//
//  private func toggleSettings() {
//    showSettings.toggle()
//  }
//
//  private func onHoverButton(hover: Bool) {
//    if hover {
//      NSCursor.pointingHand.push()
//    } else {
//      NSCursor.pop()
//    }
//  }
//}
//
//private enum Constants {
//  static let gutter: CGFloat = 60
//  static let headerHeight: CGFloat = 36
//}
