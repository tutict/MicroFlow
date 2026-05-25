package com.microflow.bootstrap;

import io.quarkus.runtime.Quarkus;
import io.quarkus.runtime.annotations.QuarkusMain;

@QuarkusMain
public class MicroFlowApplication {

    public static void main(String[] args) {
        Quarkus.run(args);
    }
}
