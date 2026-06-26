/// A saved CB8 server (the hybrid "server mode"). Tokens/cookies live in the
/// cookie jar, not here — this just remembers how to reach a server.
class Connection {
  const Connection({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.lastUsername,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String? lastUsername;

  /// Sentinel id for the always-present on-device library.
  static const localId = 'local';

  @override
  bool operator ==(Object other) =>
      other is Connection &&
      other.id == id &&
      other.name == name &&
      other.baseUrl == baseUrl &&
      other.lastUsername == lastUsername;

  @override
  int get hashCode => Object.hash(id, name, baseUrl, lastUsername);
}
