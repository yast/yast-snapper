require "yaml"

def fixtures_file(file)
  File.expand_path(File.join("../fixtures", file), __FILE__)
end

def load_yaml_fixture(file)
  YAML.load_file(fixtures_file(file))
end

