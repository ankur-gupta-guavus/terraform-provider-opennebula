# -------------------------------------------------------------------------- #
# Copyright 2002-2018, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'rotp'

# 2F Token
class SunstoneOPTP

    def self.build(secret, issuer)
        totp = ROTP::TOTP.new(secret, :issuer => issuer)
        new(totp)
    end

    def initialize(totp)
        @totp = totp
        @five_minutes = 5 * 60
    end

    def verify(token)
        @totp.verify(token,
                     :drift_ahead => @five_minutes,
                     :drift_behind => @five_minutes)
    rescue StandardError => e
        raise e
    end

    def provisioning_uri(account_name)
        @totp.provisioning_uri(account_name)
    end

end
