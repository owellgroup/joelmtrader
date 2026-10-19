package com.wayaspot.forexbot.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.wayaspot.forexbot.config.AppProps;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/** Thin client for the Python trading engine (internal network only). */
@Service
public class EngineClient {
    private final RestClient client;

    public EngineClient(AppProps props) {
        SimpleClientHttpRequestFactory rf = new SimpleClientHttpRequestFactory();
        rf.setConnectTimeout(5000);
        rf.setReadTimeout(60000);
        this.client = RestClient.builder()
                .baseUrl(props.getEngineUrl())
                .requestFactory(rf)
                .defaultHeader("X-Api-Key", props.getEngineApiKey())
                .build();
    }

    public JsonNode get(String uri) {
        try {
            return client.get().uri(uri).retrieve().body(JsonNode.class);
        } catch (RestClientResponseException e) {
            throw fail(e);
        } catch (Exception e) {
            throw new EngineException("Trading engine unreachable: " + e.getMessage(), 503);
        }
    }

    public JsonNode post(String uri, Object body) {
        try {
            return client.post().uri(uri).contentType(MediaType.APPLICATION_JSON)
                    .body(body == null ? java.util.Map.of() : body).retrieve().body(JsonNode.class);
        } catch (RestClientResponseException e) {
            throw fail(e);
        } catch (Exception e) {
            throw new EngineException("Trading engine unreachable: " + e.getMessage(), 503);
        }
    }

    public JsonNode put(String uri, Object body) {
        try {
            return client.put().uri(uri).contentType(MediaType.APPLICATION_JSON)
                    .body(body).retrieve().body(JsonNode.class);
        } catch (RestClientResponseException e) {
            throw fail(e);
        } catch (Exception e) {
            throw new EngineException("Trading engine unreachable: " + e.getMessage(), 503);
        }
    }

    private EngineException fail(RestClientResponseException e) {
        String msg = e.getResponseBodyAsString();
        try {
            JsonNode n = new com.fasterxml.jackson.databind.ObjectMapper().readTree(msg);
            if (n.has("detail")) msg = n.get("detail").asText();
        } catch (Exception ignored) { }
        return new EngineException(msg == null || msg.isBlank() ? "Engine error" : msg, e.getStatusCode().value());
    }
}
