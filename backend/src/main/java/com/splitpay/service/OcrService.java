package com.splitpay.service;

import com.splitpay.config.SplitPayProperties;
import com.splitpay.exception.ApiException;
import net.sourceforge.tess4j.Tesseract;
import net.sourceforge.tess4j.TesseractException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.io.File;

/**
 * OCR via Tess4J — the Java replacement for the Node service's tesseract.js usage (utils/ocr.js).
 *
 * <p>Reads an image file and returns the raw recognized text. The {@code eng.traineddata} file
 * already present in the backend folder is used (data path + language come from config).
 */
@Service
public class OcrService {

    private final SplitPayProperties properties;

    public OcrService(SplitPayProperties properties) {
        this.properties = properties;
    }

    /** Equivalent of {@code extractTextFromImage(filepath)}. */
    public String extractTextFromImage(File imageFile) {
        Tesseract tesseract = new Tesseract();
        tesseract.setDatapath(properties.getOcr().getDataPath());
        tesseract.setLanguage(properties.getOcr().getLanguage());
        try {
            return tesseract.doOCR(imageFile);
        } catch (TesseractException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "OCR failed! " + e.getMessage());
        } catch (LinkageError | RuntimeException e) {
            // The native Tesseract/leptonica library or the traineddata file may be missing on the
            // host (common on slim containers). Those surface as UnsatisfiedLinkError /
            // NoClassDefFoundError (LinkageError) or IllegalStateException — none of which are a
            // TesseractException. Convert them into a clean 503 instead of an opaque 500/crash.
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                    "OCR engine is unavailable. Ensure Tesseract and the '"
                            + properties.getOcr().getLanguage() + "' language data are installed.");
        }
    }
}
