# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module Lighthouse
  class Form526ClaimPdfCheck
    include Sidekiq::Job

    FORM_526_DOC_LABELS = [
      'VA 21-526 Veterans Application for Compensation or Pension',
      'VA 21-526EZ, Fully Developed Claim (Compensation)'
    ].freeze

    sidekiq_options retry: 3

    # @param submission_id [Integer] The {Form526Submission} id
    def perform(submission_id)
      submission = Form526Submission.find(submission_id)
      submitted_claim_id = submission.submitted_claim_id

      has_pdf = claim_has_526_pdf?(submission, submitted_claim_id)

      Rails.logger.info(
        'Form526ClaimPdfCheck result',
        {
          form526_submission_id: submission_id,
          submitted_claim_id:,
          has_pdf_in_claim: has_pdf
        }
      )
    end

    private

    def claim_has_526_pdf?(submission, submitted_claim_id)
      icn = submission.account.icn
      service = BenefitsClaims::Service.new(icn)
      raw_response = service.get_claim(submitted_claim_id)
      raw_response_body = raw_response.is_a?(String) ? JSON.parse(raw_response) : raw_response

      supporting_documents = raw_response_body.dig('data', 'attributes', 'supportingDocuments') || []
      supporting_documents.any? { |doc| FORM_526_DOC_LABELS.include?(doc['documentTypeLabel']) }
    end
  end
end
