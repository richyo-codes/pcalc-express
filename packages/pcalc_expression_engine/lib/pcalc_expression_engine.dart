export 'src/backend.dart'
    show
        BackendCapabilities,
        BackendKind,
        ExpressionBackend,
        ExpressionEngineInfo,
        backendDebugLoggingEnabled,
        getLastErrorMessage,
        initializeTinyExpr,
        selectedBackendInfo,
        setBackendPreference,
        setBackendDebugLoggingEnabled;
export 'src/backend_probe.dart' show canUseCling, canUseRoot;
export 'src/engine.dart' show evaluateExpression;
