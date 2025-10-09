import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// A screen that handles incoming shared media (images and videos)
/// from the Android share sheet.
class ShareHandlerScreen extends StatefulWidget {
  const ShareHandlerScreen({super.key});

  @override
  State<ShareHandlerScreen> createState() => _ShareHandlerScreenState();
}

class _ShareHandlerScreenState extends State<ShareHandlerScreen> {
  // List to store shared media files
  List<SharedMediaFile> _sharedFiles = [];

  // Subscriptions for receiving shared intents
  StreamSubscription? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSharing();
  }

  /// Initialize sharing intent listeners
  void _initializeSharing() {
    // For sharing while the app is running
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            setState(() {
              _sharedFiles = value;
            });

            // Log received files
            debugPrint(
              "Shared files received while running: ${value.map((f) => f.path).join(", ")}",
            );

            // You can process the shared files here
            _processSharedFiles(value);
          },
          onError: (err) {
            debugPrint("Error receiving shared files: $err");
          },
        );

    // For sharing when the app is opened from the share sheet (app was closed)
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        setState(() {
          _sharedFiles = value;
        });

        // Log received files
        debugPrint(
          "Shared files received on app start: ${value.map((f) => f.path).join(", ")}",
        );

        // Process the shared files
        _processSharedFiles(value);

        // Reset the intent after processing
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  /// Process the received shared files
  void _processSharedFiles(List<SharedMediaFile> files) {
    for (var file in files) {
      debugPrint("Processing file: ${file.path}");
      debugPrint(
        "File type: ${file.type}",
      ); // Type: SharedMediaType.image or SharedMediaType.video

      // Add your custom processing logic here
      // For example, you could:
      // - Upload the files to your server
      // - Save them to local storage
      // - Share them in a chat
      // - Open them in an editor
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Media Handler'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Received Media Files',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share images or videos from your gallery to test this feature.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _sharedFiles.isEmpty
                            ? Colors.orange[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _sharedFiles.isEmpty
                            ? 'No files received yet'
                            : '${_sharedFiles.length} file(s) received',
                        style: TextStyle(
                          color: _sharedFiles.isEmpty
                              ? Colors.orange[900]
                              : Colors.green[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // List of shared files
            Expanded(
              child: _sharedFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No shared files yet',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.grey[400]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share images or videos from another app',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _sharedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _sharedFiles[index];
                        final isImage = file.type == SharedMediaType.image;

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isImage
                                  ? Colors.blue[100]
                                  : Colors.purple[100],
                              child: Icon(
                                isImage ? Icons.image : Icons.videocam,
                                color: isImage ? Colors.blue : Colors.purple,
                              ),
                            ),
                            title: Text(
                              file.path.split('/').last,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Type: ${isImage ? 'Image' : 'Video'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Path: ${file.path}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () {
                                _showFileDetails(file);
                              },
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),

            // Clear button
            if (_sharedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _sharedFiles.clear();
                      });
                      ReceiveSharingIntent.instance.reset();
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show detailed information about a shared file
  void _showFileDetails(SharedMediaFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('File Name', file.path.split('/').last),
            const Divider(),
            _buildDetailRow(
              'Type',
              file.type == SharedMediaType.image ? 'Image' : 'Video',
            ),
            const Divider(),
            _buildDetailRow('Full Path', file.path),
            if (file.thumbnail != null) ...[
              const Divider(),
              _buildDetailRow('Thumbnail', file.thumbnail!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
