// Code generated by mockery v2.38.0. DO NOT EDIT.

package shareddownloadmocks

import (
	fftypes "github.com/hyperledger/firefly-common/pkg/fftypes"
	mock "github.com/stretchr/testify/mock"
)

// Callbacks is an autogenerated mock type for the Callbacks type
type Callbacks struct {
	mock.Mock
}

// SharedStorageBatchDownloaded provides a mock function with given fields: payloadRef, data
func (_m *Callbacks) SharedStorageBatchDownloaded(payloadRef string, data []byte) (*fftypes.UUID, error) {
	ret := _m.Called(payloadRef, data)

	if len(ret) == 0 {
		panic("no return value specified for SharedStorageBatchDownloaded")
	}

	var r0 *fftypes.UUID
	var r1 error
	if rf, ok := ret.Get(0).(func(string, []byte) (*fftypes.UUID, error)); ok {
		return rf(payloadRef, data)
	}
	if rf, ok := ret.Get(0).(func(string, []byte) *fftypes.UUID); ok {
		r0 = rf(payloadRef, data)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*fftypes.UUID)
		}
	}

	if rf, ok := ret.Get(1).(func(string, []byte) error); ok {
		r1 = rf(payloadRef, data)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// SharedStorageBlobDownloaded provides a mock function with given fields: hash, size, payloadRef, dataID
func (_m *Callbacks) SharedStorageBlobDownloaded(hash fftypes.Bytes32, size int64, payloadRef string, dataID *fftypes.UUID) error {
	ret := _m.Called(hash, size, payloadRef, dataID)

	if len(ret) == 0 {
		panic("no return value specified for SharedStorageBlobDownloaded")
	}

	var r0 error
	if rf, ok := ret.Get(0).(func(fftypes.Bytes32, int64, string, *fftypes.UUID) error); ok {
		r0 = rf(hash, size, payloadRef, dataID)
	} else {
		r0 = ret.Error(0)
	}

	return r0
}

// NewCallbacks creates a new instance of Callbacks. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewCallbacks(t interface {
	mock.TestingT
	Cleanup(func())
}) *Callbacks {
	mock := &Callbacks{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}