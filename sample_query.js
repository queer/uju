const _ = {
  _debug: {
    // user-friendly query name. may be attached to telemetry, etc. optional.
    name: "someQuery",
  },
  // Filtering applied to the metadata before final results are selected out.
  filter: [
    {
      op: "$eq",
      // JSON Pointer, RFC 6901. Points to a valid value in the target
      // metadata. Clients that have metadata that doesn't contain this key
      // will be ignored by this query.
      path: "/foo/bar",
      // A value to compare the target metadata key against.
      with: {value: "baz"}
    },
    {
      op: "$ne",
      path: "/foo/baz",
      // JSON pointer to a possibly-same-pointer value in the target metadata.
      // Clients that have metadata that doesn't contain this key will be
      // ignored by this query.
      with: {path: "/foo/bar"}
    },
    {
      // A custom filtering operation added by an extension. The name of the
      // extension is on the left of the $, and the name of the operation is
      // on the right. This is an example operation that checks if the value
      // at the pointer contains the given value as a substring.
      op: "ext$substring",
      path: "/foo/quux",
      with: {value: "baz"}
    },
    {
      // Logical operations don't need a pointer; instead, the `with` key
      // contains a set of filters to be checked.
      op: "$and",
      with: [
        {
          op: "$ne",
          path: "/foo/bar",
          with: {value: 123}
        },
        {
          op: "$ne",
          path: "/foo/baz",
          with: {value: 456}
        },
      ],
    },
    {
      // Logical operations can be nested.
      op: "$or",
      with: [
        {
          op: "$and",
          with: [
            {
              op: "$eq",
              path: "/foo/bar",
              with: {value: 123}
            },
            {
              op: "$eq",
              path: "/foo/baz",
              with: {value: 456}
            },
          ],
        },
        {
          op: "$and",
          with: [
            {
              op: "$ne",
              path: "/foo/bar",
              with: {value: 123}
            },
            {
              op: "$ne",
              path: "/foo/baz",
              with: {value: 456}
            },
          ],
        },
      ],
    },
  ],
  // Final clients matching the metadata filter are selected with the following
  // properties. Optional.
  select: {
    // Ordering of the final results. This option is not super useful on its
    // own. Optional.
    ordering: [
      {$asc: "/foo/bar"},
      {$desc: "/foo/baz"}
    ],
    // The number of clients to return. If omitted, all clients matching the
    // filter will be returned. Optional.
    limit: 10,
  },
}
