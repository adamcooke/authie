# frozen_string_literal: true

module Authie
  VERSION_FILE_ROOT = File.expand_path('../../VERSION', __dir__)
  VERSION = if File.file?(VERSION_FILE_ROOT)
              File.read(VERSION_FILE_ROOT).strip.sub(/\Av/, '')
            else
              '0.0.0.dev'
            end
end
