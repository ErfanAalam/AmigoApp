enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  system,
  document,
  attachment,
}

enum MessageStatus { sent, delivered, read }

enum ChatRole { member, admin }

enum ConversationType { dm, group, community_group }
