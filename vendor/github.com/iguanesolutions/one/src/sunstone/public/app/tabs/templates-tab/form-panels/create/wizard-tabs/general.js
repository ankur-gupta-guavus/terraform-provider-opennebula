/* -------------------------------------------------------------------------- */
/* Copyright 2002-2019, OpenNebula Project, OpenNebula Systems                */
/*                                                                            */
/* Licensed under the Apache License, Version 2.0 (the "License"); you may    */
/* not use this file except in compliance with the License. You may obtain    */
/* a copy of the License at                                                   */
/*                                                                            */
/* http://www.apache.org/licenses/LICENSE-2.0                                 */
/*                                                                            */
/* Unless required by applicable law or agreed to in writing, software        */
/* distributed under the License is distributed on an "AS IS" BASIS,          */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   */
/* See the License for the specific language governing permissions and        */
/* limitations under the License.                                             */
/* -------------------------------------------------------------------------- */

define(function(require) {
  /*
    DEPENDENCIES
   */

  var Locale = require('utils/locale');
  var Tips = require('utils/tips');
  var CapacityCreate = require('./general/capacity-create');
  var WizardFields = require('utils/wizard-fields');
  var Config = require('sunstone-config');
  var UserInputs = require('utils/user-inputs');
  var UniqueId = require('utils/unique-id');
  var OpenNebula = require('opennebula');
  var UsersTable = require("tabs/users-tab/datatable");
  var GroupTable = require("tabs/groups-tab/datatable");
  var OpenNebulaHost = require("opennebula/host");

  /*
    TEMPLATES
   */

  var TemplateHTML = require('hbs!./general/html');

  /*
    CONSTANTS
   */

  var WIZARD_TAB_ID = require('./general/wizardTabId');

  /*
    CONSTRUCTOR
   */

  function WizardTab(opts) {
    if (!Config.isTemplateCreationTabEnabled(opts.tabId, 'general')) {
      throw "Wizard Tab not enabled";
    }

    this.wizardTabId = WIZARD_TAB_ID + UniqueId.id();
    this.icon = 'fa-laptop';
    this.title = Locale.tr("General");

    if (opts.listener != undefined){
      this.listener = opts.listener;
    }

    var opts = {
      "select": true,
      "selectOptions": {
        "multiple_choice": false
      }
    };

    this.usersTable = new UsersTable("UsersTable" + UniqueId.id(), opts);
    this.groupTable = new GroupTable("GroupTable" + UniqueId.id(), opts);
  }

  WizardTab.prototype.constructor = WizardTab;
  WizardTab.prototype.html = _html;
  WizardTab.prototype.setup = _setup;
  WizardTab.prototype.onShow = _onShow;
  WizardTab.prototype.retrieve = _retrieve;
  WizardTab.prototype.fill = _fill;

  return WizardTab;

  /*
    FUNCTION DEFINITIONS
   */

  function _html() {
    return TemplateHTML({
      'capacityCreateHTML': CapacityCreate.html(),
      'logos': Config.vmLogos,
      'usersDatatable': this.usersTable.dataTableHTML,
      'groupDatatable': this.groupTable.dataTableHTML
    });
  }

  function _onShow(context, panelForm) {
    if (panelForm.action == 'create') {
      $('#NAME', context)
        .removeAttr('disabled')
        .attr("required", "")
        .prop('wizard_field_disabled', false);
    } else if (panelForm.action == 'update') {
      $('#NAME', context)
        .attr("disabled", "disabled")
        .removeAttr("required")
        .prop('wizard_field_disabled', true);
    }

    if (panelForm.resource == "VirtualRouterTemplate"){
      $("input[wizard_field=VROUTER]", context).attr("checked", "checked");
    }

    //context.foundation('slider', 'reflow');
  }
  function convertCostNumber(number){
    if(number >= 1000000){
      number = (number/1000000).toFixed(6)
      return number.toString()+"M";
    }
    else if(number >= 1000){
      number = (number/1000).toFixed(6)
      return number.toString()+"K";
    }
    return number.toFixed(6);
  }

  function _setup(context) {
    var that = this;

    this.usersTable.initialize();
    this.usersTable.refreshResourceTableSelect();
    this.groupTable.initialize();
    this.groupTable.refreshResourceTableSelect();

    $(document).on('click', "[href='#" + this.wizardTabId + "']", function(){
      //context.foundation('slider', 'reflow');
    });

    context.on("change", "#MEMORY_COST", function() {
      CapacityCreate.calculatedRealMemory(context);
    });

    context.on("change", "#MEMORY_UNIT_COST", function() {
      CapacityCreate.calculatedRealMemory(context);
    });

     context.on("change", "#CPU_COST", function() {
      CapacityCreate.calculatedRealCpu(context);
    });

    context.on("change", "#DISK_COST", function() {
      that.disk = parseFloat(document.getElementById('DISK_COST').value);
      if(!isNaN(that.disk)){
        that.templateDISKS = JSON.parse(localStorage.getItem("disksJSON"));
        if (that.templateDISKS){
          OpenNebula.Image.list({
            timeout: true,
            success: function(request, obj_files){
              var totalGB = 0;
              $.each(that.templateDISKS, function(ikey, ivalue){
                if (ivalue.IMAGE || ivalue.IMAGE_ID){
                  $.each(obj_files, function(jkey, jvalue){
                    if ((ivalue.IMAGE && ivalue.IMAGE === jvalue.IMAGE.NAME && ivalue.IMAGE_UNAME === jvalue.IMAGE.UNAME) || (ivalue.IMAGE_ID && ivalue.IMAGE_ID === jvalue.IMAGE.ID)){
                      totalGB += jvalue.IMAGE.SIZE / 1024;
                    }
                  });
                } else {
                  totalGB += ivalue.SIZE / 1024;
                }
              });
              var totalCostDisk = 0;
              if (!isNaN(totalGB)){
                totalCostDisk = totalGB * that.disk;
                document.getElementById('total_value_disk').textContent = convertCostNumber(totalCostDisk * 24 * 30);
                CapacityCreate.totalCost();
              } else {
                document.getElementById('total_value_disk').textContent = totalCostDisk;
              }
              $(".total_disk_cost", context).show();
            }
          });
        }
      } else {
        document.getElementById('total_value_disk').textContent = 0;
      }
    });

    context.on("change", "#LOGO", function() {
      $("#template_create_logo", context).show();
      $("#template_create_logo", context).html('<span  class="">' +
          '<img src="' + $(this).val() + '">' +
        '</span>');
    });

    context.on("change", "input[name='hypervisor']", function() {
      if (this.value == "vcenter"){
        $("#vcenter_template_ref", context).attr("required", "");
        $("#vcenter_instance_id", context).attr("required", "");
        $("#vcenter_ccr_ref", context).attr("required", "");
        $("#MEMORY", context).attr("pattern", "^([048]|\\d*[13579][26]|\\d*[24680][048])$");
        $('.only_kvm').hide();
        $('.only_lxd').hide();
        $('.only_vcenter').show();
      } else {
        $("#vcenter_template_ref", context).removeAttr("required");
        $("#vcenter_instance_id", context).removeAttr("required");
        $("#vcenter_ccr_ref", context).removeAttr("required");
        $("#MEMORY", context).removeAttr("pattern");
        $('.only_kvm').show();
        $('.only_vcenter').hide();
        if (this.value != "lxd")
        {
            $('.only_lxd').hide();
            $('.not_lxd').show();
            $('.raw_type').val('kvm');
        }
      }
      // There is another listener in context.js setup

      // Needs proper LXD view, this is just a workaround
        // All KVM settings are available in LXD plus
        // Privileged, Profile and Security Nesting

      if (this.value == "lxd"){
        $('.only_lxd').show();
        $('.not_lxd').hide();
        $('.raw_type').val('lxd');
      }
    });

    CapacityCreate.setup($("div.capacityCreate", context));

    if(that.listener != undefined){
      $(context).on("change", "input[wizard_field=VROUTER]", function(){
        that.listener.notify();
      });
    }

    if (config["mode"] === "kvm"){
      $("#kvmRadio", context).click();
      $("#template_hypervisor_form", context).hide();
      $('.only_kvm').show();
      $('.only_vcenter').hide();
    } else if (config["mode"] === "vcenter"){
      $("#vcenterRadio", context).click();
      $("#template_hypervisor_form", context).hide();
      $('.only_kvm').hide();
      $('.only_vcenter').show();
    }

    fillLXDProfiles(context)
  }

  function fillLXDProfiles(context){
    OpenNebulaHost.lxdProfilesInfo({
      data : {},
      timeout: true,
      success: function (request, lxdProfilesInfo){
        if ($("#lxd_profile", context).html() === undefined){
          lxdprofiles = lxdProfilesInfo;

          var html = "<select id=\"lxd_profile\">";
          html += "<option value=\"\">" + " " + "</option>";
          $.each(lxdprofiles, function(i, lxdprofile){
            html += "<option value='" + lxdprofile + "'>" + lxdprofile + "</option>";
          });
          html += "</select>";
          $("#lxd_profile_label", context).append(html);
        }

      },
      error: function(request, error_json){
        console.error("There was an error requesting lxd info: " +
                      error_json.error.message);
      }
    });
  }

  function _retrieve(context) {
    var templateJSON = WizardFields.retrieve(context);
    if (templateJSON["HYPERVISOR"] == 'vcenter') {
      templateJSON["VCENTER_TEMPLATE_REF"] = WizardFields.retrieveInput($("#vcenter_template_ref", context));
      templateJSON["VCENTER_CCR_REF"] = WizardFields.retrieveInput($("#vcenter_ccr_ref", context));
      templateJSON["VCENTER_INSTANCE_ID"] = WizardFields.retrieveInput($("#vcenter_instance_id", context));

      if (Config.isFeatureEnabled("vcenter_vm_folder")) {
        templateJSON["VCENTER_VM_FOLDER"] = WizardFields.retrieveInput($("#vcenter_vm_folder", context))
      }
    }

    if (templateJSON["HYPERVISOR"] == 'lxd') {
      templateJSON["LXD_SECURITY_PRIVILEGED"] = WizardFields.retrieveInput($("#lxd_security_privileged", context));
      templateJSON["LXD_PROFILE"] = WizardFields.retrieveInput($("#lxd_profile", context));
      templateJSON["LXD_SECURITY_NESTING"] = WizardFields.retrieveInput($("#lxd_security_nesting", context));
    }

    var sunstone_template = {};

    if ($('#sunstone_network_select:checked', context).length > 0) {
      sunstone_template["NETWORK_SELECT"] = "NO"
    }

    if (!$.isEmptyObject(sunstone_template)) {
      templateJSON['SUNSTONE'] = sunstone_template;
    }

    var userInputs = {};

    // Retrieve Resource Pool Attribute
    var rpInput = $(".vcenter_rp_input", context);
    if (rpInput.length > 0) {
      var rpModify = WizardFields.retrieveInput($('.modify_rp', rpInput));
      var rpInitial = WizardFields.retrieveInput($('.initial_rp', rpInput));
      var rpParams = WizardFields.retrieveInput($('.available_rps', rpInput));

      if (rpModify === 'fixed' && rpInitial !== '') {
        templateJSON['VCENTER_RESOURCE_POOL'] = rpInitial;
      } else if (rpModify === 'list' && rpParams !== '') {
        var rpUserInputs = UserInputs.marshall({
            type: 'list',
            description: Locale.tr("Which resource pool you want this VM to run in?"),
            initial: rpInitial,
            params: WizardFields.retrieveInput($('.available_rps', rpInput))
          });

        userInputs['VCENTER_RESOURCE_POOL'] = rpUserInputs;
      }
    }

    // Since the USER_INPUTS section is not enabled for vCenter, we can assume that there are no more user inputs defined
    if (!$.isEmptyObject(userInputs)) {
      templateJSON['USER_INPUTS'] = userInputs;
    }

    $.extend(true, templateJSON, CapacityCreate.retrieve($("div.capacityCreate", context)));

    if (templateJSON['MEMORY_COST'] && templateJSON['MEMORY_UNIT_COST'] && templateJSON['MEMORY_UNIT_COST'] == "GB") {
      templateJSON['MEMORY_COST'] = templateJSON['MEMORY_COST'] / 1024;
    }
    if (templateJSON['DISK_COST']) {
      templateJSON['DISK_COST'] = (templateJSON['DISK_COST'] / 1024).toString();
    }

    var as_uid = this.usersTable.retrieveResourceTableSelect();
    if (as_uid){
      templateJSON["AS_UID"] = as_uid;
    }

    var as_gid = this.groupTable.retrieveResourceTableSelect();
    if (as_gid){
      templateJSON["AS_GID"] = as_gid;
    }
    return templateJSON;
  }

  function _fill(context, templateJSON) {

    if (templateJSON['MEMORY_COST'] && templateJSON['MEMORY_UNIT_COST'] && templateJSON['MEMORY_UNIT_COST'] == "GB") {
      templateJSON['MEMORY_COST'] = templateJSON['MEMORY_COST'] * 1024;
    }
    if (templateJSON['DISK_COST']) {
      templateJSON['DISK_COST'] = templateJSON['DISK_COST'] * 1024;
    }

    that.templateDISKS = $.extend(true, {}, templateJSON.DISK);
    localStorage.setItem("disksJSON", JSON.stringify(that.templateDISKS));
    var sunstone_template = templateJSON.SUNSTONE;
    if (sunstone_template) {
      if (sunstone_template["NETWORK_SELECT"] &&
          sunstone_template["NETWORK_SELECT"].toUpperCase() == "NO") {
        $("#sunstone_network_select", context).attr("checked", "checked");
      }

      delete sunstone_template["NETWORK_SELECT"];
    }

    if (Config.isFeatureEnabled("vcenter_vm_folder")) {
      if (templateJSON["HYPERVISOR"] == 'vcenter' &&
        templateJSON["VCENTER_VM_FOLDER"]) {
        WizardFields.fillInput($("#vcenter_vm_folder", context), templateJSON["VCENTER_VM_FOLDER"]);
      }
    } else {
      $(".vcenter_vm_folder_input", context).remove();
    }

    delete templateJSON["VCENTER_VM_FOLDER"];

    if (templateJSON["HYPERVISOR"] == 'vcenter') {
      var publicClouds = templateJSON["PUBLIC_CLOUD"];

      if (publicClouds != undefined) {
        if (!$.isArray(publicClouds)){
          publicClouds = [publicClouds];
        }

        $.each(publicClouds, function(){
          if(this["TYPE"] == "vcenter"){
            WizardFields.fillInput($("#vcenter_template_ref", context), this["VCENTER_TEMPLATE_REF"]);
            return false;
          }
        });
      }
    }

    // LXD specific attributes
    if (templateJSON["HYPERVISOR"] == 'lxd') {
		fillLXD(context, templateJSON)
    }

    if (templateJSON["HYPERVISOR"]) {
      $("input[name='hypervisor'][value='"+templateJSON["HYPERVISOR"]+"']", context).trigger("click")
      delete templateJSON["HYPERVISOR"];
    }

    if (templateJSON["USER_INPUTS"]) {

      if (templateJSON["USER_INPUTS"]["VCENTER_RESOURCE_POOL"]) {
        var rp = UserInputs.unmarshall(templateJSON["USER_INPUTS"]["VCENTER_RESOURCE_POOL"]);
        $('.modify_rp', context).val('list');
        $('.initial_rp', context).val(rp.initial);
        $('.available_rps', context).val(rp.params);

        delete templateJSON["USER_INPUTS"]["VCENTER_RESOURCE_POOL"];
      }
    }

    if (templateJSON["VCENTER_RESOURCE_POOL"]) {
      $('.modify_rp', context).val('fixed');
      WizardFields.fillInput($('.initial_rp', context), templateJSON["VCENTER_RESOURCE_POOL"]);

      delete templateJSON["VCENTER_RESOURCE_POOL"];
    }

    if (templateJSON["VCENTER_TEMPLATE_REF"]){
      WizardFields.fillInput($("#vcenter_template_ref", context), templateJSON["VCENTER_TEMPLATE_REF"]);
      delete templateJSON["VCENTER_TEMPLATE_REF"];
    }

    if (templateJSON["VCENTER_CCR_REF"]){
      WizardFields.fillInput($("#vcenter_ccr_ref", context), templateJSON["VCENTER_CCR_REF"]);
      delete templateJSON["VCENTER_CCR_REF"];
    }

    if (templateJSON["VCENTER_INSTANCE_ID"]){
      WizardFields.fillInput($("#vcenter_instance_id", context), templateJSON["VCENTER_INSTANCE_ID"]);
      delete templateJSON["VCENTER_INSTANCE_ID"];
    }

    CapacityCreate.fill($("div.capacityCreate", context), templateJSON);

    if (templateJSON["AS_UID"]){
      var asuidJSON = templateJSON["AS_UID"];
      var selectedResources = {
        ids : asuidJSON
      };
      this.usersTable.selectResourceTableSelect(selectedResources);
      delete templateJSON["AS_UID"];
    }

    if (templateJSON["AS_GID"]){
      var asgidJSON = templateJSON["AS_GID"];
      var selectedResources = {
        ids : asgidJSON
      };
      this.groupTable.selectResourceTableSelect(selectedResources);
      delete templateJSON["AS_GID"];
    }

    WizardFields.fill(context, templateJSON);
  }

  function fillLXD(context, templateJSON) {
    if (templateJSON["LXD_SECURITY_PRIVILEGED"]){
      WizardFields.fillInput($("#lxd_security_privileged", context), templateJSON["LXD_SECURITY_PRIVILEGED"]);
      delete templateJSON["LXD_SECURITY_PRIVILEGED"];
    }

    if (templateJSON["LXD_PROFILE"]){
      WizardFields.fillInput($("#lxd_profile", context), templateJSON["LXD_PROFILE"]);
      delete templateJSON["LXD_PROFILE"];
    }

    if (templateJSON["LXD_SECURITY_NESTING"]){
      WizardFields.fillInput($("#lxd_security_nesting", context), templateJSON["LXD_SECURITY_NESTING"]);
      delete templateJSON["LXD_SECURITY_NESTING"];
    }
  }

});
