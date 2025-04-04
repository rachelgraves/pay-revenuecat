require "test_helper"

module Pay
  class RevenuecatWebhooksControllerTest < ActionDispatch::IntegrationTest
    include Pay::Engine.routes.url_helpers
    include Pay::Revenuecat::Engine.routes.url_helpers

    def setup
      @pay_user = users(:revenuecat)
      @pay_customer = pay_customers(:revenuecat)
    end

    test "should handle INITIAL_PURCHASE event" do
      assert_difference "Pay::Webhook.count" do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_revenuecat_path, params: initial_purchase_params, as: :json
          assert_response :success
        end
      end

      assert_difference "Pay::Charge.count" do
        perform_enqueued_jobs
      end
    end

    test "should handle RENEWAL event" do
      subscription = create_subscription(initial_purchase_params)
      create_initial_charge(initial_purchase_params, subscription)

      assert_difference "Pay::Webhook.count" do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_revenuecat_path, params: renewal_params, as: :json
          assert_response :success
        end
      end

      assert_difference "Pay::Charge.count" do
        perform_enqueued_jobs
      end
    end

    test "should handle CANCELLATION event" do
      subscription = create_subscription(initial_purchase_params)
      create_initial_charge(initial_purchase_params, subscription)

      assert_difference "Pay::Webhook.count" do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_revenuecat_path, params: cancellation_params, as: :json
          assert_response :success
        end
      end

      assert_changes -> { subscription.reload.status }, to: "canceled" do
        perform_enqueued_jobs
      end
    end

    test "should handle EXPIRATION event" do
      subscription = create_subscription(initial_purchase_params)
      create_initial_charge(initial_purchase_params, subscription)

      assert_difference "Pay::Webhook.count" do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_revenuecat_path, params: expiration_params, as: :json
          assert_response :success
        end
      end

      assert_changes -> { subscription.reload.status }, to: "canceled" do
        perform_enqueued_jobs
      end
    end
    # test "should handle revenuecat post requests" do
    #   post webhooks_revenuecat_path
    #   assert_response :bad_request
    # end
    #
    # test "should parse a revenuecat webhook" do
    #   # pay_customer = pay_customers(:revenuecat)
    #   # pay_customer.update(processor_id: stripe_event.data.object.customer)
    #   assert_difference "Pay::Webhook.count" do
    #     assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
    #       post webhooks_revenuecat_path, params: revenuecat_params, as: :json
    #       assert_response :success
    #     end
    #   end
    #
    #   assert_difference "Pay::Charge.count" do
    #     perform_enqueued_jobs
    #   end
    # end

    private

    def create_subscription(payload)
      Pay::Revenuecat::Subscription.create!(
        name: "todo: Figure out what should go here",
        processor_plan: payload["event"]["product_id"],
        processor_id: payload["event"]["original_transaction_id"],
        current_period_start: 27.days.ago,
        current_period_end: 1.month.from_now.beginning_of_month,
        status: :active,
        customer: @pay_customer
      )
    end

    def create_initial_charge(payload, subscription)
      Pay::Revenuecat::Charge.create!(
        subscription: subscription,
        processor_id: payload["event"]["transaction_id"],
        amount: 9.99,
        customer: @pay_customer
      )
    end

    def initial_purchase_params
      JSON.parse(
        file_fixture("initial_purchase.json").read
      )
    end

    def renewal_params
      JSON.parse(
        file_fixture("renewal.json").read
      )
    end

    def expiration_params
      JSON.parse(
        file_fixture("expiration.json").read
      )
    end

    def cancellation_params
      JSON.parse(
        file_fixture("cancellation.json").read
      )
    end
  end
end
