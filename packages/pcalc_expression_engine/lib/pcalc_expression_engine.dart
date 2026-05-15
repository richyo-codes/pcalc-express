export 'src/backend.dart'
    show
        BackendCapabilities,
        BackendKind,
        ExpressionBackend,
        ExpressionEngineInfo,
        getLastErrorMessage,
        initializeTinyExpr,
        selectedBackendInfo,
        setBackendPreference;
export 'src/backend_probe.dart' show canUseCling, canUseRoot;
export 'src/engine.dart' show evaluateExpression;
