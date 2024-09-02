package test

import (
	"fmt"
	"testing"

	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	stage "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
)

var (
	region = "us-east-1"
)

func TestVpcModule(t *testing.T) {
	// t.Parallel()

	testDataFolder := "../"

	// Make a copy of the terraform module to a temporary directory.
	// This allows running multiple tests in parallel
	// against the same terraform module.
	rootFolder := stage.CopyTerraformFolderToTemp(t, "../..", "examples/vpc")

	stage.RunTestStage(t, "setup", func() {
		terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
			// The path to where our Terraform code is located
			TerraformDir: rootFolder,

			// Variables to pass to our Terraform code using -var options
			// Vars: map[string]interface{}{
			// 	"instance_name": expectedName,
			// 	"instance_type": instanceType,
			// },

			// Environment variables to set when running Terraform
			// EnvVars: map[string]string{
			// 	"AWS_DEFAULT_REGION": awsRegion,
			// },
		})

		stage.SaveTerraformOptions(t, testDataFolder, terraformOptions)

		terraform.InitAndApply(t, terraformOptions)
	})

	stage.RunTestStage(t, "validate", func() {
		terraformOptions := stage.LoadTerraformOptions(t, testDataFolder)
		var publicSubnetIds []string
		var privateSubnetIds []string
		terraform.OutputStruct(t, terraformOptions, "public_subnet_ids", &publicSubnetIds)
		terraform.OutputStruct(t, terraformOptions, "private_subnet_ids", &privateSubnetIds)

		// validate public subnets tags
		for _, subnetID := range publicSubnetIds {
			assert.NoError(t, validatePublicSubnetTags(t, "adserver", subnetID))
		}

		// validate private subnets tags
		for _, subnetID := range privateSubnetIds {
			assert.NoError(t, validatePrivateSubnetTags(t, "adserver", subnetID))
		}

		// validate public subnets associated with a route table
		// that has internet gateway
		for _, subnetID := range publicSubnetIds {
			assert.True(t, aws.IsPublicSubnet(t, subnetID, region))
		}

		// validate that private subnets have a nat gateway
		// with a public ip attached
		for _, subnetID := range privateSubnetIds {
			valid, err := validateNatGateway(t, subnetID)
			assert.NoError(t, err)
			assert.True(t, valid)
		}
	})

	stage.RunTestStage(t, "teardown", func() {
		terraformOptions := stage.LoadTerraformOptions(t, testDataFolder)
		terraform.Destroy(t, terraformOptions)
	})
}

func validatePublicSubnetTags(t *testing.T, clusterName string, subnetID string) error {
	subnetTags := aws.GetTagsForSubnet(t, subnetID, region)

	// cluster tag is set
	testingTag, containsTestingTag := subnetTags[fmt.Sprintf("kubernetes.io/cluster/%s", clusterName)]

	assert.True(t, containsTestingTag)
	assert.Equal(t, "", testingTag)

	// load balancer tag is set
	testingTag, containsTestingTag = subnetTags["kubernetes.io/role/elb"]

	assert.True(t, containsTestingTag)
	assert.Equal(t, "1", testingTag)

	return nil
}

func validatePrivateSubnetTags(t *testing.T, clusterName string, subnetID string) error {
	subnetTags := aws.GetTagsForSubnet(t, subnetID, region)

	// cluster tag is set
	testingTag, containsTestingTag := subnetTags[fmt.Sprintf("kubernetes.io/cluster/%s", clusterName)]

	assert.True(t, containsTestingTag)
	assert.Equal(t, "", testingTag)

	// internal load balancer tag is set
	testingTag, containsTestingTag = subnetTags["kubernetes.io/role/internal-elb"]

	assert.True(t, containsTestingTag)
	assert.Equal(t, "1", testingTag)

	// karpenter tag is set
	testingTag, containsTestingTag = subnetTags["karpenter.sh/discovery"]

	assert.True(t, containsTestingTag)
	assert.Equal(t, clusterName, testingTag)

	return nil
}

func validateNatGateway(t *testing.T, subnetID string) (bool, error) {
	sess, err := aws.NewAuthenticatedSession(region)
	if err != nil {
		t.Fatal(err)
	}

	// Create a new EC2 client
	svc := ec2.New(sess)

	subnetIdFilterName := "association.subnet-id"

	subnetIdFilter := ec2.Filter{
		Name:   &subnetIdFilterName,
		Values: []*string{&subnetID},
	}

	// Describe Route tables
	input := &ec2.DescribeRouteTablesInput{
		Filters: []*ec2.Filter{&subnetIdFilter},
	}
	result, err := svc.DescribeRouteTables(input)
	if err != nil {
		return false, err
	}

	var gatewayID string

	for _, association := range result.RouteTables {
		for _, route := range association.Routes {
			if route.NatGatewayId != nil {
				gatewayID = *route.NatGatewayId
			}
		}
	}

	gatewayIdFilterName := "nat-gateway-id"

	gatewayIdFilter := ec2.Filter{
		Name:   &gatewayIdFilterName,
		Values: []*string{&gatewayID},
	}

	// Describe NAT Gateways
	gatewayInput := &ec2.DescribeNatGatewaysInput{
		Filter: []*ec2.Filter{&gatewayIdFilter},
	}
	gatewayResult, err := svc.DescribeNatGateways(gatewayInput)
	if err != nil {
		return false, err
	}

	for _, gateway := range gatewayResult.NatGateways {
		for _, address := range gateway.NatGatewayAddresses {
			if address.PublicIp != nil {
				return true, nil
			}
		}
	}

	return false, nil
}
