package com.splitpay.service;

import com.splitpay.config.SplitPayProperties;
import com.splitpay.exception.ApiException;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.Set;

/**
 * Saves uploaded bill images to the local {@code uploads/} folder — the Java equivalent of the
 * multer disk-storage config (middleware/upload.js).
 *
 * <p>Security additions over the original Node setup:
 * <ol>
 *   <li>Extension whitelist (jpeg/jpg/png/pdf).</li>
 *   <li>MIME magic-bytes check — validates the file header matches the declared extension so a
 *       disguised executable cannot slip through with a .jpg name.</li>
 *   <li>Path-traversal guard — the resolved path is canonicalized and asserted to stay inside
 *       the uploads directory.</li>
 *   <li>Timestamp-only filename — the original filename never touches the file system.</li>
 * </ol>
 */
@Service
public class FileStorageService {

    private static final Set<String> ALLOWED_EXTENSIONS = Set.of("jpeg", "jpg", "png", "pdf");

    // Magic bytes for each allowed type (first N bytes of the file header).
    private static final byte[] MAGIC_JPEG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
    private static final byte[] MAGIC_PNG  = {(byte) 0x89, 0x50, 0x4E, 0x47};
    private static final byte[] MAGIC_PDF  = {0x25, 0x50, 0x44, 0x46}; // %PDF

    private final Path uploadDir;

    public FileStorageService(SplitPayProperties properties) {
        this.uploadDir = Paths.get(properties.getUploads().getDir()).toAbsolutePath().normalize();
    }

    /** Persists the file and returns its relative path (stored as billImageUrl). */
    public String store(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("No file uploaded");
        }
        String original = StringUtils.cleanPath(
                file.getOriginalFilename() == null ? "" : file.getOriginalFilename());
        String ext = StringUtils.getFilenameExtension(original);
        if (ext == null || !ALLOWED_EXTENSIONS.contains(ext.toLowerCase())) {
            throw ApiException.badRequest("Only images (jpg/png) and PDFs are allowed");
        }

        // Read the magic bytes and validate the file header matches the extension.
        try (InputStream in = file.getInputStream()) {
            validateMagicBytes(in, ext.toLowerCase());
        } catch (IOException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Could not read uploaded file");
        }

        try {
            Files.createDirectories(uploadDir);
            String filename = Instant.now().toEpochMilli() + "." + ext.toLowerCase();
            Path target = uploadDir.resolve(filename).normalize();

            // Path-traversal guard: ensure the resolved target is still inside uploadDir.
            if (!target.startsWith(uploadDir)) {
                throw ApiException.badRequest("Invalid file path");
            }

            file.transferTo(target.toAbsolutePath());
            // Return a relative path string (same as the Node app: uploads/<filename>)
            return uploadDir.getFileName().toString() + "/" + filename;
        } catch (IOException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to store file: " + e.getMessage());
        }
    }

    /**
     * Loads a previously stored file back for download, given the {@code billImageUrl} recorded on
     * the expense. Only the filename component of the stored path is trusted — it's re-resolved
     * against {@code uploadDir} with the same path-traversal guard used when storing, since the
     * stored string ultimately reaches here from client-controlled expense data.
     */
    public Resource loadAsResource(String storedPath) {
        String filename = Paths.get(storedPath).getFileName().toString();
        Path target = uploadDir.resolve(filename).normalize();
        if (!target.startsWith(uploadDir)) {
            throw ApiException.badRequest("Invalid file path");
        }
        if (!Files.isRegularFile(target) || !Files.isReadable(target)) {
            throw ApiException.notFound("File not found");
        }
        try {
            return new UrlResource(target.toUri());
        } catch (MalformedURLException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to load file");
        }
    }

    /** Content type for a stored file, based on its (whitelisted) extension. */
    public String contentTypeFor(String storedPath) {
        String ext = StringUtils.getFilenameExtension(storedPath);
        if (ext == null) {
            return MediaType.APPLICATION_OCTET_STREAM_VALUE;
        }
        return switch (ext.toLowerCase()) {
            case "jpeg", "jpg" -> MediaType.IMAGE_JPEG_VALUE;
            case "png" -> MediaType.IMAGE_PNG_VALUE;
            case "pdf" -> "application/pdf";
            default -> MediaType.APPLICATION_OCTET_STREAM_VALUE;
        };
    }

    private void validateMagicBytes(InputStream in, String ext) throws IOException {
        byte[] magic = switch (ext) {
            case "jpeg", "jpg" -> MAGIC_JPEG;
            case "png"         -> MAGIC_PNG;
            case "pdf"         -> MAGIC_PDF;
            default            -> null;
        };
        if (magic == null) return; // no check defined, extension whitelist is sufficient
        byte[] header = in.readNBytes(magic.length);
        for (int i = 0; i < magic.length; i++) {
            if (i >= header.length || header[i] != magic[i]) {
                throw ApiException.badRequest(
                        "File content does not match the declared type (" + ext + ")");
            }
        }
    }
}
