package com.microflow.testing;

import static io.restassured.RestAssured.given;

import io.restassured.http.Header;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import java.util.List;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

public class QuarkusRestTemplate {

    public <T> ResponseEntity<T> getForEntity(String url, Class<T> responseType) {
        return toEntity(given().when().get(url), responseType);
    }

    public <T> ResponseEntity<T> postForEntity(String url, Object request, Class<T> responseType) {
        var entity = request instanceof HttpEntity<?> httpEntity ? httpEntity : new HttpEntity<>(request, jsonHeaders());
        return exchange(url, HttpMethod.POST, entity, responseType);
    }

    public <T> ResponseEntity<T> exchange(
            String url,
            HttpMethod method,
            HttpEntity<?> entity,
            Class<T> responseType
    ) {
        var spec = requestSpec(entity);
        var response = switch (method.name()) {
            case "GET" -> spec.when().get(url);
            case "POST" -> spec.when().post(url);
            case "PUT" -> spec.when().put(url);
            case "DELETE" -> spec.when().delete(url);
            default -> throw new IllegalArgumentException("Unsupported HTTP method: " + method);
        };
        return toEntity(response, responseType);
    }

    private RequestSpecification requestSpec(HttpEntity<?> entity) {
        var spec = given();
        if (entity == null) {
            return spec;
        }
        for (var entry : entity.getHeaders().entrySet()) {
            for (var value : entry.getValue()) {
                spec.header(entry.getKey(), value);
            }
        }
        if (entity.getBody() != null) {
            var contentType = entity.getHeaders().getContentType();
            if (contentType == null) {
                spec.contentType("application/json");
            }
            spec.body(entity.getBody());
        }
        return spec;
    }

    private <T> ResponseEntity<T> toEntity(Response response, Class<T> responseType) {
        var headers = new HttpHeaders();
        for (Header header : response.getHeaders()) {
            headers.add(header.getName(), header.getValue());
        }
        return new ResponseEntity<>(
                responseBody(response, responseType),
                headers,
                HttpStatusCode.valueOf(response.statusCode())
        );
    }

    @SuppressWarnings("unchecked")
    private <T> T responseBody(Response response, Class<T> responseType) {
        if (responseType == Void.class) {
            return null;
        }
        if (responseType == String.class) {
            return (T) response.asString();
        }
        if (responseType == byte[].class) {
            return (T) response.asByteArray();
        }
        return response.as(responseType);
    }

    private HttpHeaders jsonHeaders() {
        var headers = new HttpHeaders();
        headers.setAccept(List.of(MediaType.APPLICATION_JSON));
        headers.setContentType(MediaType.APPLICATION_JSON);
        return headers;
    }
}
