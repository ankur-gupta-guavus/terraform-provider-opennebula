// Code generated by protoc-gen-go. DO NOT EDIT.
// source: google/cloud/datacatalog/v1beta1/table_spec.proto

package datacatalog

import (
	fmt "fmt"
	math "math"

	proto "github.com/golang/protobuf/proto"
	_ "google.golang.org/genproto/googleapis/api/annotations"
)

// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf

// This is a compile-time assertion to ensure that this generated file
// is compatible with the proto package it is being compiled against.
// A compilation error at this line likely means your copy of the
// proto package needs to be updated.
const _ = proto.ProtoPackageIsVersion3 // please upgrade the proto package

// Table source type.
type TableSourceType int32

const (
	// Default unknown type.
	TableSourceType_TABLE_SOURCE_TYPE_UNSPECIFIED TableSourceType = 0
	// Table view.
	TableSourceType_BIGQUERY_VIEW TableSourceType = 2
	// BigQuery native table.
	TableSourceType_BIGQUERY_TABLE TableSourceType = 5
)

var TableSourceType_name = map[int32]string{
	0: "TABLE_SOURCE_TYPE_UNSPECIFIED",
	2: "BIGQUERY_VIEW",
	5: "BIGQUERY_TABLE",
}

var TableSourceType_value = map[string]int32{
	"TABLE_SOURCE_TYPE_UNSPECIFIED": 0,
	"BIGQUERY_VIEW":                 2,
	"BIGQUERY_TABLE":                5,
}

func (x TableSourceType) String() string {
	return proto.EnumName(TableSourceType_name, int32(x))
}

func (TableSourceType) EnumDescriptor() ([]byte, []int) {
	return fileDescriptor_2effb41fca72136b, []int{0}
}

// Describes a BigQuery table.
type BigQueryTableSpec struct {
	// Output only. The table source type.
	TableSourceType TableSourceType `protobuf:"varint,1,opt,name=table_source_type,json=tableSourceType,proto3,enum=google.cloud.datacatalog.v1beta1.TableSourceType" json:"table_source_type,omitempty"`
	// Output only.
	//
	// Types that are valid to be assigned to TypeSpec:
	//	*BigQueryTableSpec_ViewSpec
	//	*BigQueryTableSpec_TableSpec
	TypeSpec             isBigQueryTableSpec_TypeSpec `protobuf_oneof:"type_spec"`
	XXX_NoUnkeyedLiteral struct{}                     `json:"-"`
	XXX_unrecognized     []byte                       `json:"-"`
	XXX_sizecache        int32                        `json:"-"`
}

func (m *BigQueryTableSpec) Reset()         { *m = BigQueryTableSpec{} }
func (m *BigQueryTableSpec) String() string { return proto.CompactTextString(m) }
func (*BigQueryTableSpec) ProtoMessage()    {}
func (*BigQueryTableSpec) Descriptor() ([]byte, []int) {
	return fileDescriptor_2effb41fca72136b, []int{0}
}

func (m *BigQueryTableSpec) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_BigQueryTableSpec.Unmarshal(m, b)
}
func (m *BigQueryTableSpec) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_BigQueryTableSpec.Marshal(b, m, deterministic)
}
func (m *BigQueryTableSpec) XXX_Merge(src proto.Message) {
	xxx_messageInfo_BigQueryTableSpec.Merge(m, src)
}
func (m *BigQueryTableSpec) XXX_Size() int {
	return xxx_messageInfo_BigQueryTableSpec.Size(m)
}
func (m *BigQueryTableSpec) XXX_DiscardUnknown() {
	xxx_messageInfo_BigQueryTableSpec.DiscardUnknown(m)
}

var xxx_messageInfo_BigQueryTableSpec proto.InternalMessageInfo

func (m *BigQueryTableSpec) GetTableSourceType() TableSourceType {
	if m != nil {
		return m.TableSourceType
	}
	return TableSourceType_TABLE_SOURCE_TYPE_UNSPECIFIED
}

type isBigQueryTableSpec_TypeSpec interface {
	isBigQueryTableSpec_TypeSpec()
}

type BigQueryTableSpec_ViewSpec struct {
	ViewSpec *ViewSpec `protobuf:"bytes,2,opt,name=view_spec,json=viewSpec,proto3,oneof"`
}

type BigQueryTableSpec_TableSpec struct {
	TableSpec *TableSpec `protobuf:"bytes,3,opt,name=table_spec,json=tableSpec,proto3,oneof"`
}

func (*BigQueryTableSpec_ViewSpec) isBigQueryTableSpec_TypeSpec() {}

func (*BigQueryTableSpec_TableSpec) isBigQueryTableSpec_TypeSpec() {}

func (m *BigQueryTableSpec) GetTypeSpec() isBigQueryTableSpec_TypeSpec {
	if m != nil {
		return m.TypeSpec
	}
	return nil
}

func (m *BigQueryTableSpec) GetViewSpec() *ViewSpec {
	if x, ok := m.GetTypeSpec().(*BigQueryTableSpec_ViewSpec); ok {
		return x.ViewSpec
	}
	return nil
}

func (m *BigQueryTableSpec) GetTableSpec() *TableSpec {
	if x, ok := m.GetTypeSpec().(*BigQueryTableSpec_TableSpec); ok {
		return x.TableSpec
	}
	return nil
}

// XXX_OneofWrappers is for the internal use of the proto package.
func (*BigQueryTableSpec) XXX_OneofWrappers() []interface{} {
	return []interface{}{
		(*BigQueryTableSpec_ViewSpec)(nil),
		(*BigQueryTableSpec_TableSpec)(nil),
	}
}

// Table view specification.
type ViewSpec struct {
	// Required. Output only. The query that defines the table view.
	ViewQuery            string   `protobuf:"bytes,1,opt,name=view_query,json=viewQuery,proto3" json:"view_query,omitempty"`
	XXX_NoUnkeyedLiteral struct{} `json:"-"`
	XXX_unrecognized     []byte   `json:"-"`
	XXX_sizecache        int32    `json:"-"`
}

func (m *ViewSpec) Reset()         { *m = ViewSpec{} }
func (m *ViewSpec) String() string { return proto.CompactTextString(m) }
func (*ViewSpec) ProtoMessage()    {}
func (*ViewSpec) Descriptor() ([]byte, []int) {
	return fileDescriptor_2effb41fca72136b, []int{1}
}

func (m *ViewSpec) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_ViewSpec.Unmarshal(m, b)
}
func (m *ViewSpec) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_ViewSpec.Marshal(b, m, deterministic)
}
func (m *ViewSpec) XXX_Merge(src proto.Message) {
	xxx_messageInfo_ViewSpec.Merge(m, src)
}
func (m *ViewSpec) XXX_Size() int {
	return xxx_messageInfo_ViewSpec.Size(m)
}
func (m *ViewSpec) XXX_DiscardUnknown() {
	xxx_messageInfo_ViewSpec.DiscardUnknown(m)
}

var xxx_messageInfo_ViewSpec proto.InternalMessageInfo

func (m *ViewSpec) GetViewQuery() string {
	if m != nil {
		return m.ViewQuery
	}
	return ""
}

// Normal BigQuery table spec.
type TableSpec struct {
	// Output only. If the table is a dated shard, i.e., with name pattern
	// `[prefix]YYYYMMDD`, `grouped_entry` is the Data Catalog resource name of
	// the date sharded grouped entry, for example,
	// `projects/{project_id}/locations/{location}/entrygroups/{entry_group_id}/entries/{entry_id}`.
	// Otherwise, `grouped_entry` is empty.
	GroupedEntry         string   `protobuf:"bytes,1,opt,name=grouped_entry,json=groupedEntry,proto3" json:"grouped_entry,omitempty"`
	XXX_NoUnkeyedLiteral struct{} `json:"-"`
	XXX_unrecognized     []byte   `json:"-"`
	XXX_sizecache        int32    `json:"-"`
}

func (m *TableSpec) Reset()         { *m = TableSpec{} }
func (m *TableSpec) String() string { return proto.CompactTextString(m) }
func (*TableSpec) ProtoMessage()    {}
func (*TableSpec) Descriptor() ([]byte, []int) {
	return fileDescriptor_2effb41fca72136b, []int{2}
}

func (m *TableSpec) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_TableSpec.Unmarshal(m, b)
}
func (m *TableSpec) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_TableSpec.Marshal(b, m, deterministic)
}
func (m *TableSpec) XXX_Merge(src proto.Message) {
	xxx_messageInfo_TableSpec.Merge(m, src)
}
func (m *TableSpec) XXX_Size() int {
	return xxx_messageInfo_TableSpec.Size(m)
}
func (m *TableSpec) XXX_DiscardUnknown() {
	xxx_messageInfo_TableSpec.DiscardUnknown(m)
}

var xxx_messageInfo_TableSpec proto.InternalMessageInfo

func (m *TableSpec) GetGroupedEntry() string {
	if m != nil {
		return m.GroupedEntry
	}
	return ""
}

// Spec for a group of BigQuery tables with name pattern `[prefix]YYYYMMDD`.
// Context:
// https://cloud.google.com/bigquery/docs/partitioned-tables#partitioning_versus_sharding
type BigQueryDateShardedSpec struct {
	// Output only. The Data Catalog resource name of the dataset entry the
	// current table belongs to, for example,
	// `projects/{project_id}/locations/{location}/entrygroups/{entry_group_id}/entries/{entry_id}`.
	Dataset string `protobuf:"bytes,1,opt,name=dataset,proto3" json:"dataset,omitempty"`
	// Output only. The table name prefix of the shards. The name of any given
	// shard is `[table_prefix]YYYYMMDD`, for example, for shard
	// `MyTable20180101`, the `table_prefix` is `MyTable`.
	TablePrefix string `protobuf:"bytes,2,opt,name=table_prefix,json=tablePrefix,proto3" json:"table_prefix,omitempty"`
	// Output only. Total number of shards.
	ShardCount           int64    `protobuf:"varint,3,opt,name=shard_count,json=shardCount,proto3" json:"shard_count,omitempty"`
	XXX_NoUnkeyedLiteral struct{} `json:"-"`
	XXX_unrecognized     []byte   `json:"-"`
	XXX_sizecache        int32    `json:"-"`
}

func (m *BigQueryDateShardedSpec) Reset()         { *m = BigQueryDateShardedSpec{} }
func (m *BigQueryDateShardedSpec) String() string { return proto.CompactTextString(m) }
func (*BigQueryDateShardedSpec) ProtoMessage()    {}
func (*BigQueryDateShardedSpec) Descriptor() ([]byte, []int) {
	return fileDescriptor_2effb41fca72136b, []int{3}
}

func (m *BigQueryDateShardedSpec) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_BigQueryDateShardedSpec.Unmarshal(m, b)
}
func (m *BigQueryDateShardedSpec) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_BigQueryDateShardedSpec.Marshal(b, m, deterministic)
}
func (m *BigQueryDateShardedSpec) XXX_Merge(src proto.Message) {
	xxx_messageInfo_BigQueryDateShardedSpec.Merge(m, src)
}
func (m *BigQueryDateShardedSpec) XXX_Size() int {
	return xxx_messageInfo_BigQueryDateShardedSpec.Size(m)
}
func (m *BigQueryDateShardedSpec) XXX_DiscardUnknown() {
	xxx_messageInfo_BigQueryDateShardedSpec.DiscardUnknown(m)
}

var xxx_messageInfo_BigQueryDateShardedSpec proto.InternalMessageInfo

func (m *BigQueryDateShardedSpec) GetDataset() string {
	if m != nil {
		return m.Dataset
	}
	return ""
}

func (m *BigQueryDateShardedSpec) GetTablePrefix() string {
	if m != nil {
		return m.TablePrefix
	}
	return ""
}

func (m *BigQueryDateShardedSpec) GetShardCount() int64 {
	if m != nil {
		return m.ShardCount
	}
	return 0
}

func init() {
	proto.RegisterEnum("google.cloud.datacatalog.v1beta1.TableSourceType", TableSourceType_name, TableSourceType_value)
	proto.RegisterType((*BigQueryTableSpec)(nil), "google.cloud.datacatalog.v1beta1.BigQueryTableSpec")
	proto.RegisterType((*ViewSpec)(nil), "google.cloud.datacatalog.v1beta1.ViewSpec")
	proto.RegisterType((*TableSpec)(nil), "google.cloud.datacatalog.v1beta1.TableSpec")
	proto.RegisterType((*BigQueryDateShardedSpec)(nil), "google.cloud.datacatalog.v1beta1.BigQueryDateShardedSpec")
}

func init() {
	proto.RegisterFile("google/cloud/datacatalog/v1beta1/table_spec.proto", fileDescriptor_2effb41fca72136b)
}

var fileDescriptor_2effb41fca72136b = []byte{
	// 500 bytes of a gzipped FileDescriptorProto
	0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xff, 0x94, 0x53, 0x4d, 0x6f, 0xd3, 0x40,
	0x10, 0xad, 0x13, 0x01, 0xf5, 0xa4, 0x1f, 0xc9, 0x5e, 0x08, 0x15, 0xa8, 0xa9, 0x4f, 0x51, 0x91,
	0x6c, 0xa5, 0x1c, 0x39, 0xc5, 0xa9, 0x81, 0x88, 0x02, 0xa9, 0x93, 0x14, 0xb5, 0x1c, 0xac, 0xb5,
	0x3d, 0x75, 0x2d, 0xb9, 0xd9, 0xc5, 0x5e, 0xa7, 0xe4, 0xc7, 0x70, 0xe0, 0x9f, 0xf5, 0x67, 0x20,
	0x4e, 0xc8, 0x63, 0xa7, 0x09, 0x48, 0x55, 0xe1, 0xe6, 0x7d, 0x3b, 0xef, 0xcd, 0x9b, 0x37, 0x5e,
	0xe8, 0x45, 0x42, 0x44, 0x09, 0x5a, 0x41, 0x22, 0xf2, 0xd0, 0x0a, 0xb9, 0xe2, 0x01, 0x57, 0x3c,
	0x11, 0x91, 0x35, 0xef, 0xf9, 0xa8, 0x78, 0xcf, 0x52, 0xdc, 0x4f, 0xd0, 0xcb, 0x24, 0x06, 0xa6,
	0x4c, 0x85, 0x12, 0xac, 0x53, 0x52, 0x4c, 0xa2, 0x98, 0x6b, 0x14, 0xb3, 0xa2, 0xec, 0xed, 0x57,
	0xa2, 0x5c, 0xc6, 0xd6, 0x65, 0x8c, 0x49, 0xe8, 0xf9, 0x78, 0xc5, 0xe7, 0xb1, 0x48, 0x4b, 0x89,
	0xbd, 0x67, 0x6b, 0x05, 0x29, 0x66, 0x22, 0x4f, 0x03, 0x2c, 0xaf, 0x8c, 0xef, 0x35, 0x68, 0xd9,
	0x71, 0x74, 0x9a, 0x63, 0xba, 0x98, 0x14, 0xad, 0xc7, 0x12, 0x03, 0xe6, 0x43, 0xab, 0xf2, 0x41,
	0xb5, 0x9e, 0x5a, 0x48, 0x6c, 0x6b, 0x1d, 0xad, 0xbb, 0x73, 0xd4, 0x33, 0x1f, 0xf2, 0x63, 0x96,
	0x3a, 0xc4, 0x9c, 0x2c, 0x24, 0xda, 0xf5, 0xdb, 0x7e, 0xdd, 0xdd, 0x55, 0x7f, 0xa2, 0x6c, 0x08,
	0xfa, 0x3c, 0xc6, 0x1b, 0x1a, 0xb5, 0x5d, 0xeb, 0x68, 0xdd, 0xc6, 0xd1, 0xe1, 0xc3, 0xda, 0x67,
	0x31, 0xde, 0x14, 0x16, 0xdf, 0x6d, 0xb8, 0x9b, 0xf3, 0xea, 0x9b, 0x9d, 0x00, 0xac, 0x62, 0x6b,
	0xd7, 0x49, 0xeb, 0xe5, 0xbf, 0xfa, 0x2c, 0xc5, 0x74, 0xb5, 0x3c, 0xd8, 0x0d, 0xd0, 0x8b, 0x79,
	0x49, 0xcc, 0x30, 0x61, 0x73, 0xd9, 0x92, 0x19, 0x00, 0xe4, 0xf8, 0x6b, 0x11, 0x16, 0xc5, 0xa1,
	0x17, 0xb3, 0xd5, 0x5c, 0x1a, 0x84, 0x22, 0x34, 0x2e, 0x40, 0x5f, 0xc5, 0xf8, 0x01, 0xb6, 0xa3,
	0x54, 0xe4, 0x12, 0x43, 0x0f, 0x67, 0xea, 0x8e, 0xd3, 0xbd, 0xed, 0xd7, 0x7f, 0xf5, 0x0d, 0xe8,
	0xac, 0x9b, 0x2a, 0xdd, 0x72, 0x19, 0x67, 0x66, 0x20, 0xae, 0x2d, 0xa7, 0xa8, 0x77, 0xb7, 0x2a,
	0x3a, 0x9d, 0x8c, 0x1f, 0x1a, 0x3c, 0x5d, 0xee, 0xea, 0x98, 0x2b, 0x1c, 0x5f, 0xf1, 0x34, 0xc4,
	0x90, 0x5a, 0xd9, 0xf0, 0xa4, 0x50, 0xcb, 0x50, 0xfd, 0x77, 0x93, 0x25, 0x91, 0x1d, 0xc0, 0x56,
	0x19, 0xa3, 0x4c, 0xf1, 0x32, 0xfe, 0x46, 0x4b, 0xd1, 0xdd, 0x06, 0x61, 0x23, 0x82, 0xd8, 0x3e,
	0x34, 0xb2, 0xa2, 0xab, 0x17, 0x88, 0x7c, 0xa6, 0x28, 0xea, 0xba, 0x0b, 0x04, 0x0d, 0x0a, 0xe4,
	0xf0, 0x0b, 0xec, 0xfe, 0xb5, 0x7e, 0x76, 0x00, 0x2f, 0x26, 0x7d, 0xfb, 0xc4, 0xf1, 0xc6, 0x9f,
	0xa6, 0xee, 0xc0, 0xf1, 0x26, 0xe7, 0x23, 0xc7, 0x9b, 0x7e, 0x1c, 0x8f, 0x9c, 0xc1, 0xf0, 0xcd,
	0xd0, 0x39, 0x6e, 0x6e, 0xb0, 0x16, 0x6c, 0xdb, 0xc3, 0xb7, 0xa7, 0x53, 0xc7, 0x3d, 0xf7, 0xce,
	0x86, 0xce, 0xe7, 0x66, 0x8d, 0x31, 0xd8, 0xb9, 0x83, 0x88, 0xde, 0x7c, 0x64, 0x4b, 0x78, 0x1e,
	0x88, 0xeb, 0x7b, 0x17, 0x3b, 0xd2, 0x2e, 0xde, 0x57, 0x77, 0x91, 0x48, 0xf8, 0x2c, 0x32, 0x45,
	0x1a, 0x59, 0x11, 0xce, 0xe8, 0x57, 0xb7, 0x56, 0xc3, 0xdf, 0xff, 0xfc, 0x5e, 0xaf, 0x61, 0x3f,
	0x35, 0xcd, 0x7f, 0x4c, 0xd4, 0x57, 0xbf, 0x03, 0x00, 0x00, 0xff, 0xff, 0xca, 0xc2, 0x2f, 0x2d,
	0xb8, 0x03, 0x00, 0x00,
}