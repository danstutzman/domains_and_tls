#!/usr/bin/env ruby
require 'bundler'
Bundler.setup

require 'aws-sdk'
#require 'pry'
#require 'awesome_print'

# ------------------------------------------------------------------------------
#   Credentials
# ------------------------------------------------------------------------------
# pick up AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY by default from
# environment
Aws.config.update({
  region: 'us-east-1',
})
# ------------------------------------------------------------------------------

def setup_dns(domain, txt_challenge)
  top_level_domain = domain.split('.')[-2..-1].join('.')
  route53 = Aws::Route53::Client.new()
  hosted_zones = route53.list_hosted_zones_by_name({dns_name: "#{top_level_domain}."})
  hosted_zone = hosted_zones.hosted_zones.find { |zone|
    zone.name == "#{top_level_domain}."
  }
  raise "Couldn't find hosted zone with name #{top_level_domain}." if hosted_zone.nil?
  changes = []
  changes << {
    action: "UPSERT",
    resource_record_set: {
      name: "_acme-challenge.#{domain}.",
      type: "TXT",
      ttl: 60,
      resource_records: [
        value: "\"#{txt_challenge}\"",
      ],
    },
  }
p changes
  resp = route53.change_resource_record_sets({
    hosted_zone_id: hosted_zone.id,
    change_batch: {
      changes: changes,
    },
  })
  p resp
  puts 'sleeping 30...'
  sleep 30
end

def delete_dns(domain, txt_challenge)
  top_level_domain = domain.split('.')[-2..-1].join('.')
  route53 = Aws::Route53::Client.new()
  hosted_zones = route53.list_hosted_zones_by_name({dns_name: "#{top_level_domain}."})
  hosted_zone = hosted_zones.hosted_zones.find { |zone|
    zone.name == "#{top_level_domain}."
  }
  raise "Couldn't find hosted zone with name #{top_level_domain}." if hosted_zone.nil?
  changes = []
  changes << {
    action: "DELETE",
    resource_record_set: {
      name: "_acme-challenge.#{domain}.",
      type: "TXT",
      ttl: 60,
      resource_records: [
        value: "\"#{txt_challenge}\"",
      ],
    },
  }
  resp = route53.change_resource_record_sets({
    hosted_zone_id: hosted_zone.id,
    change_batch: {
      changes: changes,
    },
  })
  p resp
  sleep 10
end

if __FILE__ == $0
  hook_stage = ARGV[0]
  domain = ARGV[1]
  txt_challenge = ARGV[3]

  if hook_stage == "deploy_challenge"
    setup_dns(domain, txt_challenge)
  elsif hook_stage == "clean_challenge"
    delete_dns(domain, txt_challenge)
  end

end
