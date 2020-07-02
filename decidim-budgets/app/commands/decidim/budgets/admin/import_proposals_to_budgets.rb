# frozen_string_literal: true

module Decidim
  module Budgets
    module Admin
      # A command with all the business logic when an admin imports proposals from
      # one component to projects of a budget.
      class ImportProposalsToBudgets < Rectify::Command
        # Public: Initializes the command.
        #
        # form - A form object with the params.
        def initialize(form)
          @form = form
        end

        # Executes the command. Broadcasts these events:
        #
        # - :ok when everything is valid.
        # - :invalid if the form wasn't valid and we couldn't proceed.
        #
        # Returns nothing.
        def call
          return broadcast(:invalid) unless @form.valid?

          broadcast(:ok, create_projects_from_accepted_proposals)
        end

        private

        attr_reader :form, :project

        def create_projects_from_accepted_proposals
          transaction do
            proposals.map do |original_proposal|
              next if proposal_already_copied?(original_proposal)

              create_project_from_proposal!(original_proposal)

              project.link_resources([original_proposal], "included_proposals")
            end.compact
          end
        end

        def create_project_from_proposal!(original_proposal)
          params = {
            budget: form.budget,
            title: project_localized(original_proposal.title),
            description: project_localized(original_proposal.body),
            budget_amount: form.default_budget,
            category: original_proposal.category,
            scope: original_proposal.scope
          }

          @project = Decidim.traceability.create!(
            Project,
            form.current_user,
            params,
            visibility: "all"
          )
        end

        def proposals
          Decidim::Proposals::Proposal.where(component: origin_component).where(state: "accepted")
        end

        def origin_component
          form.origin_component
        end

        def proposal_already_copied?(original_proposal)
          original_proposal.linked_resources(:projects, "included_proposals").any? do |project|
            project.budget == form.budget
          end
        end

        def project_localized(text)
          Decidim.available_locales.inject({}) do |result, locale|
            result.update(locale => text)
          end.with_indifferent_access
        end
      end
    end
  end
end
