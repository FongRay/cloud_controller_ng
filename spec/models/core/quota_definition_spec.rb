require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::Models::QuotaDefinition, type: :model do
    let(:quota_definition) { Models::QuotaDefinition.make }

    it_behaves_like "a CloudController model", {
      :required_attributes => [
        :name,
        :non_basic_services_allowed,
        :total_services,
        :memory_limit,
      ],
      :unique_attributes => [:name]
    }

    describe ".default" do
      before { reset_database }

      it "returns the default quota" do
        Models::QuotaDefinition.default.name.should == "free"
      end
    end

    describe "#destroy" do
      it "nullifies the organization quota definition" do
        org = Models::Organization.make(:quota_definition => quota_definition)
        expect {
          quota_definition.destroy
        }.to change {
          Models::Organization.count(:id => org.id)
        }.by(-1)
      end
    end
  end
end
