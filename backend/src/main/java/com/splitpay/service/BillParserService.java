package com.splitpay.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.splitpay.config.SplitPayProperties;
import com.splitpay.model.Expense;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Parses bill images (and optionally raw text) into structured expense data using Google Gemini.
 *
 * <p>Primary path: {@link #parseBillImage} — sends the image bytes directly to Gemini Vision
 * (gemini-2.5-flash is multimodal) so Tesseract OCR is no longer needed. This is more accurate
 * on real receipts (curved text, thermal paper, low contrast) and removes the native-library
 * dependency from the hot path.
 *
 * <p>The text-only fallback {@link #parseBillText} is kept for callers that already have OCR
 * output (e.g. tests or a future manual-text endpoint).
 */
@Service
public class BillParserService {

    private static final Logger log = LoggerFactory.getLogger(BillParserService.class);

    /** Grabs the first complete {...} block — tolerates chatty model preamble. */
    private static final Pattern JSON_BLOCK = Pattern.compile("\\{[\\s\\S]*}");

    private static final String EXTRACT_PROMPT = """
            You are a precise receipt parser. Look at this bill/receipt image carefully.
            Extract every line item and return ONLY valid JSON — no explanation, no markdown fences.

            Rules:
            - "name": the item name as printed
            - "price": price per unit as a number (not a string)
            - "quantity": quantity as a number (default 1 if not shown)
            - "total": the final payable amount (after tax/service charge) as a number
            - "billName": restaurant or store name if visible, otherwise omit

            Example format:
            {
              "billName": "Spice Garden",
              "items": [
                { "name": "Paneer Butter Masala", "price": 180, "quantity": 2 },
                { "name": "Garlic Naan",          "price": 40,  "quantity": 4 }
              ],
              "total": 520
            }

            Return ONLY the JSON object. No other text.
            """;

    private final SplitPayProperties properties;
    private final ObjectMapper objectMapper;
    private final RestClient restClient;

    public BillParserService(SplitPayProperties properties, ObjectMapper objectMapper) {
        this.properties = properties;
        this.objectMapper = objectMapper;
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(10));
        factory.setReadTimeout(Duration.ofSeconds(60)); // vision calls can be slower
        this.restClient = RestClient.builder().requestFactory(factory).build();
    }

    /** Structured result: items + total + optional billName. */
    public record ParsedBill(List<Expense.Item> items, BigDecimal total, String billName) {}

    /**
     * PRIMARY PATH — send the image bytes directly to Gemini Vision; no OCR step needed.
     *
     * @param imageBytes raw bytes of the uploaded file
     * @param mimeType   e.g. "image/jpeg", "image/png" — passed straight to the API
     * @return parsed bill, or {@code null} on any failure (network, bad key, no JSON in response)
     */
    public ParsedBill parseBillImage(byte[] imageBytes, String mimeType) {
        try {
            String base64 = Base64.getEncoder().encodeToString(imageBytes);

            Map<String, Object> requestBody = Map.of(
                    "contents", List.of(Map.of(
                            "parts", List.of(
                                    Map.of("inline_data", Map.of(
                                            "mime_type", mimeType,
                                            "data", base64
                                    )),
                                    Map.of("text", EXTRACT_PROMPT)
                            )
                    ))
            );

            JsonNode response = restClient.post()
                    .uri(properties.getGemini().getUrl())
                    .contentType(MediaType.APPLICATION_JSON)
                    .header("x-goog-api-key", properties.getGemini().getApiKey())
                    .body(requestBody)
                    .retrieve()
                    .body(JsonNode.class);

            String modelResponse = response
                    .path("candidates").path(0)
                    .path("content").path("parts").path(0)
                    .path("text").asText("");

            return extractJson(modelResponse);
        } catch (Exception e) {
            log.error("Gemini Vision error: {}", e.getMessage());
            return null;
        }
    }

    /**
     * FALLBACK / TEXT PATH — kept for tests and any caller that already has OCR text.
     */
    public ParsedBill parseBillText(String ocrText) {
        try {
            String prompt = "Extract items from this receipt text and return ONLY valid JSON in the same format as described:\n\n"
                    + EXTRACT_PROMPT + "\n\nReceipt text:\n" + ocrText;

            Map<String, Object> requestBody = Map.of(
                    "contents", List.of(Map.of(
                            "parts", List.of(Map.of("text", prompt)))));

            JsonNode response = restClient.post()
                    .uri(properties.getGemini().getUrl())
                    .contentType(MediaType.APPLICATION_JSON)
                    .header("x-goog-api-key", properties.getGemini().getApiKey())
                    .body(requestBody)
                    .retrieve()
                    .body(JsonNode.class);

            String modelResponse = response
                    .path("candidates").path(0)
                    .path("content").path("parts").path(0)
                    .path("text").asText("");

            return extractJson(modelResponse);
        } catch (Exception e) {
            log.error("Gemini Text error: {}", e.getMessage());
            return null;
        }
    }

    // ----- helpers -----------------------------------------------------------------------

    private ParsedBill extractJson(String modelResponse) throws Exception {
        Matcher matcher = JSON_BLOCK.matcher(modelResponse);
        if (!matcher.find()) {
            log.error("No JSON block in Gemini response: {}", modelResponse);
            return null;
        }
        JsonNode parsed = objectMapper.readTree(matcher.group());
        return toParsedBill(parsed);
    }

    private ParsedBill toParsedBill(JsonNode parsed) {
        List<Expense.Item> items = new ArrayList<>();
        JsonNode itemsNode = parsed.path("items");
        if (itemsNode.isArray()) {
            for (JsonNode n : itemsNode) {
                items.add(Expense.Item.builder()
                        .name(n.path("name").asText(null))
                        .price(n.has("price") ? toMoney(n.path("price")) : null)
                        .quantity(n.has("quantity") ? n.path("quantity").asInt() : 1)
                        .assignedTo(new ArrayList<>())
                        .build());
            }
        }
        BigDecimal total = parsed.has("total") ? toMoney(parsed.path("total")) : null;
        String billName = parsed.has("billName") ? parsed.path("billName").asText(null) : null;
        return new ParsedBill(items, total, billName);
    }

    /** Parses a Gemini-returned numeric field as an exact 2-decimal-place money value. */
    private static BigDecimal toMoney(JsonNode node) {
        return new BigDecimal(node.asText()).setScale(2, RoundingMode.HALF_UP);
    }
}
