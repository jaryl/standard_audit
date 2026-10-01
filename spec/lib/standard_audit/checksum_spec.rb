require "rails_helper"

# json 3.0 removed the `create_additions:` option from JSON.parse, and passing
# it raises `ArgumentError: unknown keyword: create_additions`. From the
# canonical cutover on, every row with a Hash or Array field goes through
# Checksum.json_round_trip, so on json 3 each such write raised before the row
# was saved (luminality-web, LUMINALITY-WEB-1N). The gem's own lockfile pins
# json 2.x, so these examples model json 3's stricter signature directly.
RSpec.describe StandardAudit::Checksum do
  let(:fields) { StandardAudit::AuditLog::CHECKSUM_FIELDS }

  def strict_json3_parse!
    allow(JSON).to receive(:parse).and_wrap_original do |original, source, **opts|
      raise ArgumentError, "unknown keyword: create_additions" if opts.key?(:create_additions)

      original.call(source, **opts)
    end
  end

  describe ".json_round_trip" do
    it "does not pass options json 3 rejects" do
      strict_json3_parse!

      expect(described_class.json_round_trip({ run: 1, probe: [1, 2] })).to eq("run" => 1, "probe" => [1, 2])
    end

    it "never builds objects from a json_class key" do
      value = { "json_class" => "OpenStruct", "a" => 1 }

      expect(described_class.json_round_trip(value)).to eq(value)
    end
  end

  describe ".canonical_digest" do
    it "digests a row with Hash metadata under json 3" do
      strict_json3_parse!
      attrs = { "id" => SecureRandom.uuid_v7, "event_type" => "x.y", "metadata" => { "run" => 1, "probe" => 2 },
                "occurred_at" => Time.utc(2026, 10, 1, 8) }

      expect(described_class.canonical_digest(attrs, fields: fields, previous_checksum: nil)).to match(/\A\h{64}\z/)
    end
  end
end
