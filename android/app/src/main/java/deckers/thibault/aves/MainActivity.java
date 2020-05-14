package deckers.thibault.aves;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

import app.loup.streams_channel.StreamsChannel;
import deckers.thibault.aves.channelhandlers.AppAdapterHandler;
import deckers.thibault.aves.channelhandlers.ImageByteStreamHandler;
import deckers.thibault.aves.channelhandlers.ImageFileHandler;
import deckers.thibault.aves.channelhandlers.ImageOpStreamHandler;
import deckers.thibault.aves.channelhandlers.MediaStoreStreamHandler;
import deckers.thibault.aves.channelhandlers.MetadataHandler;
import deckers.thibault.aves.channelhandlers.StorageAccessStreamHandler;
import deckers.thibault.aves.channelhandlers.StorageHandler;
import deckers.thibault.aves.utils.Constants;
import deckers.thibault.aves.utils.Env;
import deckers.thibault.aves.utils.PermissionManager;
import deckers.thibault.aves.utils.Utils;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String LOG_TAG = Utils.createLogTag(MainActivity.class);

    public static final String VIEWER_CHANNEL = "deckers.thibault/aves/viewer";

    private Map<String, String> sharedEntryMap;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        handleIntent(getIntent());

        MediaStoreStreamHandler mediaStoreStreamHandler = new MediaStoreStreamHandler();

        BinaryMessenger messenger = Objects.requireNonNull(getFlutterEngine()).getDartExecutor().getBinaryMessenger();
        new MethodChannel(messenger, StorageHandler.CHANNEL).setMethodCallHandler(new StorageHandler(this));
        new MethodChannel(messenger, AppAdapterHandler.CHANNEL).setMethodCallHandler(new AppAdapterHandler(this));
        new MethodChannel(messenger, ImageFileHandler.CHANNEL).setMethodCallHandler(new ImageFileHandler(this, mediaStoreStreamHandler));
        new MethodChannel(messenger, MetadataHandler.CHANNEL).setMethodCallHandler(new MetadataHandler(this));
        new EventChannel(messenger, MediaStoreStreamHandler.CHANNEL).setStreamHandler(mediaStoreStreamHandler);

        final StreamsChannel fileAccessStreamChannel = new StreamsChannel(messenger, StorageAccessStreamHandler.CHANNEL);
        fileAccessStreamChannel.setStreamHandlerFactory(arguments -> new StorageAccessStreamHandler(this, arguments));

        final StreamsChannel imageByteStreamChannel = new StreamsChannel(messenger, ImageByteStreamHandler.CHANNEL);
        imageByteStreamChannel.setStreamHandlerFactory(arguments -> new ImageByteStreamHandler(this, arguments));

        final StreamsChannel imageOpStreamChannel = new StreamsChannel(messenger, ImageOpStreamHandler.CHANNEL);
        imageOpStreamChannel.setStreamHandlerFactory(arguments -> new ImageOpStreamHandler(this, arguments));

        new MethodChannel(messenger, VIEWER_CHANNEL).setMethodCallHandler(
                (call, result) -> {
                    if (call.method.contentEquals("getSharedEntry")) {
                        result.success(sharedEntryMap);
                        sharedEntryMap = null;
                    }
                });
    }

    private void handleIntent(Intent intent) {
        Log.i(LOG_TAG, "handleIntent intent=" + intent);
        if (intent != null && Intent.ACTION_VIEW.equals(intent.getAction())) {
            Uri uri = intent.getData();
            String mimeType = intent.getType();
            if (uri != null && mimeType != null) {
                sharedEntryMap = new HashMap<>();
                sharedEntryMap.put("uri", uri.toString());
                sharedEntryMap.put("mimeType", mimeType);
            }
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == Constants.SD_CARD_PERMISSION_REQUEST_CODE) {
            if (resultCode != RESULT_OK || data.getData() == null) {
                PermissionManager.onPermissionResult(requestCode, false);
                return;
            }

            Uri treeUri = data.getData();
            Env.setSdCardDocumentUri(this, treeUri.toString());

            // save access permissions across reboots
            final int takeFlags = data.getFlags()
                    & (Intent.FLAG_GRANT_READ_URI_PERMISSION
                    | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            getContentResolver().takePersistableUriPermission(treeUri, takeFlags);

            // resume pending action
            PermissionManager.onPermissionResult(requestCode, true);
        }
    }
}

