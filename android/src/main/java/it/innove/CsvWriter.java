package it.innove;

import android.util.Log;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

public class CsvWriter {
    private static final String TAG = CsvWriter.class.getSimpleName();

    private String fileName;
    private String header;

    public CsvWriter(String fileName, String header) {
        this.fileName = fileName;
        this.header = header;
    }

    public void append(String message) {
        try {
            File file = getOrCreateFile();

            FileOutputStream fos = new FileOutputStream(file, true);

            // StringBuilder sb = new StringBuilder();
            // for (String value : values) {
            // sb.append(value).append(",");
            // }
            // sb.deleteCharAt(sb.length() - 1).append("\n");

            fos.write(message.getBytes());
            fos.close();

            // Log.d(TAG, "Data appended to " + fileName);

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public File getOrCreateFile() throws IOException {

        File file = new File(fileName);
        if (!file.exists()) {
            boolean success = file.createNewFile();
            if (!success) {
                throw new IOException("Failed to create file: " + file.getAbsolutePath());
            }

            FileOutputStream fos = new FileOutputStream(file);
            fos.write(header.getBytes());
            fos.write("\n".getBytes());
            fos.close();
            Log.d(TAG, "File created: " + file.getAbsolutePath());
        }

        return file;
    }
}