FactoryGirl.define do
  factory :channel do
    sequence(:name) { |n| "Test Channel #{n}" }
    user { create(:user) }

    trait :public do
      is_public true
    end

    trait :private do
      is_private true
    end

  end
end
