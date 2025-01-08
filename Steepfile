D = Steep::Diagnostic

target :lib do
  check "lib"
  signature "sig"

  configure_code_diagnostics do |config|
    config[D::Ruby::UnannotatedEmptyCollection] = :hint
  end
end
