package com.akletna.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.converter.json.JacksonJsonHttpMessageConverter;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;
import tools.jackson.databind.cfg.CoercionAction;
import tools.jackson.databind.cfg.CoercionInputShape;
import tools.jackson.databind.type.LogicalType;
import java.util.List;

/** IDs and whole-number fields must never be silently rounded or parsed from strings. */
@Configuration
public class RequestJsonConfig implements WebMvcConfigurer {
    @Override
    public void extendMessageConverters(List<HttpMessageConverter<?>> converters) {
        for (int i=0; i<converters.size(); i++) {
            if (converters.get(i) instanceof JacksonJsonHttpMessageConverter json) {
                var mapper=json.getMapper().rebuild()
                        .withCoercionConfig(LogicalType.Enum, config -> config
                                .setCoercion(CoercionInputShape.Integer, CoercionAction.Fail)
                                .setCoercion(CoercionInputShape.Float, CoercionAction.Fail))
                        .withCoercionConfig(LogicalType.Integer, config -> config
                                .setCoercion(CoercionInputShape.Float, CoercionAction.Fail)
                                .setCoercion(CoercionInputShape.String, CoercionAction.Fail)
                                .setCoercion(CoercionInputShape.EmptyString, CoercionAction.Fail))
                        .build();
                // Decimal strings remain supported for exact pantry quantities.
                converters.set(i,new JacksonJsonHttpMessageConverter(mapper));
            }
        }
    }
}
