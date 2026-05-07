# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    add_group "Core", "lib/durable_huggingface_hub"
    add_group "Utils", "lib/durable_huggingface_hub/utils"
    add_group "Types", "lib/durable_huggingface_hub/types"
  end
end

require "minitest/autorun"
require "minitest/reporters"
require "webmock/minitest"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

require "huggingface_hub"

# Disable real HTTP connections in tests
WebMock.disable_net_connect!

module TestHelpers
  HF_ENDPOINT = "https://huggingface.co"

  def stub_hf_get(path, body:, status: 200, headers: {})
    stub_request(:get, "#{HF_ENDPOINT}#{path}")
      .to_return(
        status: status,
        body: body.is_a?(Hash) || body.is_a?(Array) ? body.to_json : body,
        headers: { "Content-Type" => "application/json" }.merge(headers)
      )
  end

  def stub_hf_head(path, status: 200, headers: {})
    stub_request(:head, /#{Regexp.escape(HF_ENDPOINT + path)}/)
      .to_return(status: status, headers: headers)
  end

  def stub_hf_post(path, body:, status: 200, response_body: {})
    stub_request(:post, "#{HF_ENDPOINT}#{path}")
      .with(body: body.is_a?(Hash) ? hash_including(body) : body)
      .to_return(
        status: status,
        body: response_body.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def stub_hf_delete(path, status: 200)
    stub_request(:delete, /#{Regexp.escape(HF_ENDPOINT + path)}/)
      .to_return(status: status, body: "{}", headers: { "Content-Type" => "application/json" })
  end

  def model_info_hash(overrides = {})
    {
      "id" => "bert-base-uncased",
      "sha" => "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
      "lastModified" => "2023-01-01T00:00:00.000Z",
      "tags" => ["transformers", "pytorch", "bert"],
      "pipeline_tag" => "fill-mask",
      "siblings" => [
        { "rfilename" => "config.json" },
        { "rfilename" => "pytorch_model.bin" }
      ],
      "private" => false,
      "downloads" => 1_000_000,
      "likes" => 500,
      "library_name" => "transformers",
      "author" => "google",
      "createdAt" => "2020-01-01T00:00:00.000Z"
    }.merge(overrides)
  end

  def dataset_info_hash(overrides = {})
    {
      "id" => "squad",
      "sha" => "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3",
      "lastModified" => "2023-06-01T00:00:00.000Z",
      "tags" => ["question-answering", "english"],
      "siblings" => [
        { "rfilename" => "README.md" },
        { "rfilename" => "dataset_infos.json" }
      ],
      "private" => false,
      "downloads" => 500_000,
      "likes" => 200,
      "author" => "rajpurkar",
      "createdAt" => "2020-01-01T00:00:00.000Z"
    }.merge(overrides)
  end

  def space_info_hash(overrides = {})
    {
      "id" => "stabilityai/stable-diffusion",
      "sha" => "c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4",
      "lastModified" => "2023-07-01T00:00:00.000Z",
      "tags" => ["stable-diffusion", "image-generation"],
      "private" => false,
      "likes" => 10_000,
      "author" => "stabilityai",
      "createdAt" => "2022-01-01T00:00:00.000Z"
    }.merge(overrides)
  end

  def user_hash(overrides = {})
    {
      "name" => "test-user",
      "fullname" => "Test User",
      "email" => "test@example.com",
      "type" => "user",
      "canPay" => false,
      "isPro" => false,
      "avatarUrl" => "https://huggingface.co/avatars/test.jpg",
      "orgs" => []
    }.merge(overrides)
  end

  def build_api(token: "hf_test_token_1234567890")
    DurableHuggingfaceHub::HfApi.new(token: token)
  end
end

Minitest::Test.include TestHelpers
