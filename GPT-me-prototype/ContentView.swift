//
//  ContentView.swift
//  GPT-me-prototype
//
//  Created by Benji on 2025-09-07.
//

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ContentView: View {
    @State private var conversations: [Conversation] = []
    @State private var selection: Conversation.ID?
    @State private var hoveredConversationID: Conversation.ID?

    var body: some View {
        NavigationSplitView {
            List {
                Section("Actions") {
                    Button {
                        createConversation()
                    } label: {
                        Label("New Chat", systemImage: "plus.bubble")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))

                    Button {
                        // Search action
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                }

                Section("Conversations") {
                    if conversations.isEmpty {
                        Text("No conversations yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(conversations) { conversation in
                            Button {
                                selection = conversation.id
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                    Text(conversation.title)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(GlassRowButtonStyle(isSelected: selection == conversation.id))
                            .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                            .onHover { isHovering in
                                hoveredConversationID = isHovering ? conversation.id : (hoveredConversationID == conversation.id ? nil : hoveredConversationID)
                            }
                            .overlay(alignment: .trailing) {
                                Button(role: .destructive) {
                                    delete(conversation)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .opacity(hoveredConversationID == conversation.id ? 1 : 0)
                                .padding(.trailing, 6)
                                .animation(.easeOut(duration: 0.12), value: hoveredConversationID)
                            }
                            .contextMenu {
                                Button(role: .destructive) { delete(conversation) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { indices in
                            delete(atOffsets: indices)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        } detail: {
            if let selection,
               let index = conversations.firstIndex(where: { $0.id == selection }) {
                ChatView(
                    messages: $conversations[index].messages,
                    onFirstUserMessage: { firstText in
                        if conversations[index].title == "New Chat" {
                            conversations[index].title = String(firstText.prefix(40))
                        }
                    },
                    aiResponder: AIResponder.shared
                )
            } else {
                ZStack {
                    Color.clear
                    Text("Start a new chat or select one from the sidebar")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.thinMaterial)
            }
        }
        .onAppear { loadConversations() }
        .onChange(of: conversations) { _, _ in saveConversations() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) {
                    Image(systemName: "gear")
                }
            }
        }
    }

    private func createConversation() {
        let new = Conversation(id: UUID(), title: "New Chat", messages: [], createdAt: Date())
        conversations.insert(new, at: 0)
        selection = new.id
    }

    private func delete(_ conversation: Conversation) {
        if let idx = conversations.firstIndex(of: conversation) {
            conversations.remove(at: idx)
            if selection == conversation.id { selection = conversations.first?.id }
        }
    }

    private func delete(atOffsets offsets: IndexSet) {
        conversations.remove(atOffsets: offsets)
        if !conversations.contains(where: { $0.id == selection }) { selection = conversations.first?.id }
    }

    private func conversationsFileURL() -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return directory.appendingPathComponent("conversations.json")
    }

    private func saveConversations() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(conversations)
            try data.write(to: conversationsFileURL(), options: [.atomic])
        } catch {
            // Silently ignore for now; could add logging
        }
    }

    private func loadConversations() {
        let url = conversationsFileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let loaded = try decoder.decode([Conversation].self, from: data)
            conversations = loaded
            if let first = loaded.first { selection = first.id }
        } catch {
            // Silently ignore for now; could add logging
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
}
#endif

private struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.10 : 0.15), radius: configuration.isPressed ? 6 : 10, x: 0, y: configuration.isPressed ? 3 : 6)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Chat UI

private struct GlassRowButtonStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? .thinMaterial : .ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.28), Color.white.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: isSelected ? 1.0 : 0.75
                    )
            )
            .shadow(color: Color.black.opacity(pressed ? 0.08 : (isSelected ? 0.14 : 0.10)), radius: pressed ? 5 : 8, x: 0, y: pressed ? 2 : 4)
            .scaleEffect(pressed ? 0.997 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

private struct ChatMessage: Identifiable, Hashable, Codable {
    enum Role: String, Codable { case user, assistant }
    var id: UUID = UUID()
    let role: Role
    var text: String
    let date: Date
}

private struct Conversation: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
}

private struct ChatView: View {
    @Binding var messages: [ChatMessage]
    var onFirstUserMessage: (String) -> Void = { _ in }
    var aiResponder: AIResponder? = nil
    @State private var inputText: String = ""
    @State private var inputBarHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                    .animation(
                        .spring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.15),
                        value: messages
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, inputBarHeight + 24)
                }
                .background(.thinMaterial)
                .onChange(of: messages.count) { _, _ in
                    if let lastId = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
                .onAppear {
                    if let lastId = messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            // Floating input bar overlay
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Message", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.body)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .glassEffect()
                )


                Button {
                    send()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 24, height: 24)
                        
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: InputBarHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(InputBarHeightKey.self) { height in
                inputBarHeight = height
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial)
    }

    private func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let first = messages.isEmpty
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.15)) {
            messages.append(ChatMessage(role: .user, text: trimmed, date: Date()))
        }
        inputText = ""

        // Respond using streaming (falls back to mock streaming if unavailable)
        if let aiResponder = aiResponder {
            Task { @MainActor in
                let assistantId = UUID()
                let createdAt = Date()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.15)) {
                    messages.append(ChatMessage(id: assistantId, role: .assistant, text: "", date: createdAt))
                }
                do {
                    for try await partial in aiResponder.stream(to: trimmed) {
                        if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                                // Append-only update to avoid flicker from full struct replacement
                                messages[idx].text = partial
                        }
                    }
                } catch {
                    if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                        messages[idx].text = "(AI error) \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // Mock assistant reply with a slight delay
            sendMockResponse(to: trimmed)
        }
        if first { onFirstUserMessage(trimmed) }
    }

    private func sendMockResponse(to userText: String) {
        let replyText = "Mock: \(userText)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.15)) {
                messages.append(ChatMessage(role: .assistant, text: replyText, date: Date()))
            }
        }
    }
}

private struct InputBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant {
                bubble
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble
            }
        }
    }

    private var bubble: some View {
        let isUser = message.role == .user
        let parsed: AttributedString = (try? AttributedString(
            markdown: message.text,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(message.text)

        return Text(parsed)
            .textSelection(.enabled)
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isUser ? .ultraThinMaterial : .thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

// MARK: - AI Responder

final class AIResponder {
    static let shared: AIResponder? = {
        #if canImport(FoundationModels)
        return AIResponder()
        #else
        return nil
        #endif
    }()

    #if canImport(FoundationModels)
    private let session = LanguageModelSession()
    #endif

    func respond(to userText: String) async -> String {
        #if canImport(FoundationModels)
        do {
            let response = try await session.respond(to: userText)
            return response.content
        } catch {
            return "(AI error) " + error.localizedDescription
        }
        #else
        // Fallback when FoundationModels is unavailable
        return "Apple Intellegence is not enabled! Please enable it in settings to use GPTme."
        #endif
    }

    // Streaming interface
    func stream(to userText: String) -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        let stream = session.streamResponse(to: userText)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await snapshot in stream {
                        // Use the official snapshot content for streaming text
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        #else
        // Mock streaming: type out "Mock: <text>" character by character
        let text = "Mock: \(userText)"
        return AsyncThrowingStream { continuation in
            Task {
                var buffer = ""
                for (index, char) in text.enumerated() {
                    buffer.append(char)
                    continuation.yield(buffer)
                    try? await Task.sleep(nanoseconds: index == 0 ? 200_000_000 : 25_000_000)
                }
                continuation.finish()
            }
        }
        #endif
    }
}
